# merlinux.eu (hq6)
merlinux.eu specifically was set up as the business email server for merlinux GmbH by Janek. It's a 1-core VM hosted at Hetzner. In addition to the following guide, which was created as a "clean" mailserver setup for hq6 and dubby, we installed rspamd on hq6. We used  [mailadm](https://github.com/deltachat/mailadm) to manage mail accounts.

### Before we install the mailserver components, we should take a look at our dns setting at our dns provider.
This is the full example zone file. First you should set the A, AAAA, MX records. Also set the SPF record. Later we will add TXT records for DKIM and DMARC. Also remember, that you need to set a Reverse-DNS-Record / PTR for your FQDN. You usually do this at the hosting provider. You usually do not have to configure the Nameserver/Zone of Authority records (NS, SOA), since most providers do this for you and will let you configure your domain with an webinterface.
```
$ORIGIN merlinux.eu.
$TTL 86400
; SOA Records
@	1800	IN	SOA	ns1.first-ns.de. dns.hetzner.com. 2020111400 14400 1800 604800 1800
; NS Records
@		IN	NS	ns1.first-ns.de.
@		IN	NS	robotns2.second-ns.de.
@		IN	NS	robotns3.second-ns.com.
; MX Records
@		IN	MX	1 merlinux.eu.
; A Records
@		IN	A	95.217.159.152
; AAAA Records
@		IN	AAAA	2a01:4f9:c010:78bc::1
; TXT Records
mail._domainkey		IN	TXT	"v=DKIM1; h=sha256; k=rsa; s=email; " "p=............................" 
@		IN	TXT	"v=spf1 mx a:merlinux.eu -all"
_dmarc		IN	TXT	"v=DMARC1; p=reject; rua=mailto:your@email.com; ruf=mailto:your@email.com; adkim=r; aspf=r; rf=afrf"
```

## Install some basics (ufw, git, etckeeper, nginx, certbot)
First let's install etckeeper, which is a useful tool for keeping track of the changes in your /etc directory.
Up until now you should be root@<your-server>, if not the following commands should be run with sudo.
```
$ apt update && sudo apt full-upgrade
$ apt install etckeeper vim
$ vim /etc/etckeeper/etckeeper.conf
$ git config --global user.name "User"
$ git config --global user.email "Email"
$ git config --global core.editor "vim"
$ etckeeper init
$ etckeeper commit "init"
```

### Setup Users
```
$ apt install sudo
$ adduser <your-user>
$ adduser <your-user> sudo
$ su <your-user>

$ sudo useradd --create-home --home-dir /var/vmail --user-group --shell /usr/sbin/nologin vmail
$ sudo chown -R vmail /var/vmail
$ sudo chgrp -R vmail /var/vmail
$ sudo chmod -R 660 /var/vmail
```
Also edit the hostname an make sure to add FQDN and Hostname to
```
$ sudo vim /etc/hosts
```
It should look something like this:
```
127.0.0.1   localhost
127.0.1.1   merlinux.eu  mail

::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
```
Now let's enable passwordless sudo for your user. Visudo uses vi as editor. You can change this by running `$ sudo EDITOR=vim visudo`
```
$ sudo visudo
```
search for the line:
```
%sudo   ALL= (ALL:ALL) ALL
```
and change it to the following if you want, that all users with access to sudo, can use it without being asked for password. 
```
%sudo   ALL= (ALL:ALL) NOPASSWD: ALL
```
### Install Firewall
Depending on your choice of services open specific ports. In this example we will open a lot of ports for mail. For simplicity we will use ufw.
```
$ sudo apt install ufw nginx git unattended-upgrades sshguard

$ sudo ufw default deny incoming
$ sudo ufw default allow outgoing
$ sudo ufw allow ssh
$ sudo ufw allow http
$ sudo ufw allow https
$ sudo ufw allow 25
$ sudo ufw allow 143
$ sudo ufw allow 465
$ sudo ufw allow 587
$ sudo ufw allow 993
$ sudo ufw enable

$ sudo etckeeper commit "configure firewall"
```

### Obtain SSL certificate for your domain
In our example we will serve a webserver and a mailserver with the same domain.
[certbot](https://certbot.eff.org/lets-encrypt/debianbuster-nginx)
```
$ sudo apt install certbot python-certbot-nginx
$ sudo certbot --nginx
```
Enter Email Adress and your domain e.g. merlinux.eu

Also let Certbot redirect all traffic over https. By using the `certbot --nginx` option, Certbox will also setup a cronjob, which will take care of renewal. You should now be able to access your domain in the browser with TLS. 

Then we can prepare the webserver for the use of mailadm, by adding the following routes to our nginx config, in the SSL server block.
```
$ sudo mv /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default
$ sudo vim /etc/nginx/sites-enabled/mailsetup
```
```
server {

        listen [::]:443 ssl ipv6only=on; # managed by Certbot
        listen 443 ssl; # managed by Certbot

        server_name merlinux.eu; # managed by Certbot

        root /var/www/html;
        index index.html index.htm;

        location / {
                # First attempt to serve request as file, then
                # as directory, then fall back to displaying a 404.
                try_files $uri $uri/ =404;
        }
        
        location /new_email {
                proxy_pass http://localhost:3691/;
        }

        location /.well-known/autoconfig/mail/config-v1.1.xml {
            alias /etc/well-known/autoconfig-mail-examplecom.xml;
        }
                
        
        ssl_certificate /etc/letsencrypt/live/merlinux.eu/fullchain.pem; # managed by Certbot
        ssl_certificate_key /etc/letsencrypt/live/merlinux.eu/privkey.pem; # managed by Certbot
        include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
        ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

}

server {

        if ($host = merlinux.eu) {
                return 301 https://$host$request_uri;
        } # managed by Certbot


        listen 80 ;
        listen [::]:80 ;
        
        server_name merlinux.eu;
        return 404; # managed by Certbot
}
```

```
$ sudo systemctl restart nginx
```

This is the mentioned autoconfig file at /etc/well-known/. Just create it and edit it, if you want to use other Ports for Services.
autoconfig-mail-examplecom.xml:
```
$ sudo vim /etc/well-known/autoconfig-mail-examplecom.xml
```
```
<?xml version="1.0" encoding="UTF-8"?>

<clientConfig version="1.1">
  <emailProvider id="merlinux.eu">
    <domain>merlinux.eu</domain>
    <displayName>merlinux.eu mail</displayName>
    <displayShortName>merlinux.eu</displayShortName>
    <incomingServer type="imap">
      <hostname>merlinux.eu</hostname>
      <port>993</port>
      <socketType>SSL</socketType>
      <authentication>password-cleartext</authentication>
      <username>%EMAILADDRESS%</username>
    </incomingServer>
    <outgoingServer type="smtp">
      <hostname>merlinux.eu</hostname>
      <port>465</port>
      <socketType>SSL</socketType>
      <authentication>password-cleartext</authentication>
      <username>%EMAILADDRESS%</username>
    </outgoingServer>
  </emailProvider>
</clientConfig>
```
Remember to commit the changes you've made to your etckeeper with:
```
$ sudo etckeeper commit "<commit-message>"
```

## Install postfix and dovecot

```
$ sudo apt install dovecot-common dovecot-imapd dovecot-lmtpd dovecot-sqlite dovecot-sieve dovecot-managesieved
```
Generate Diffie-Hellman Key (this can take a while)
```
$ sudo su
$ openssl dhparam 4096 > /etc/dovecot/dh.pem
$ exit
```

### Let's go through some configfiles:

#### Dovecot
/etc/dovecot/conf.d/10-master.conf:
```

service imap-login {
  inet_listener imap {
  }
  inet_listener imaps {
  }

}

service pop3-login {
  inet_listener pop3 {
  }
  inet_listener pop3s {
  }
}

service submission-login {
  inet_listener submission {
  }
}

service lmtp {
  unix_listener /var/spool/postfix/private/dovecot-lmtp {
    mode = 0600
    group = postfix
    user = postfix
  }
}

service imap {
}

service pop3 {
}

service auth {
  unix_listener auth-userdb {
    mode = 0666
    user = postfix
    group = postfix
  }

  unix_listener /var/spool/postfix/private/auth {
    mode = 0666
    user = postfix
    group = postfix   
  }
}

service auth-worker {
}

service dict {
  unix_listener dict {
  }
}

service stats {
    unix_listener stats-reader {
        user = mailadm
        group = mailadm
        mode = 0660
    }

    unix_listener stats-writer {
        user = mailadm
        group = mailadm
        mode = 0660
    }
}
```

/etc/dovecot/conf.d/10-auth.conf
```
disable_plaintext_auth = yes

auth_mechanisms = plain login

# set this to "yes" if you want to see more logging
# eg when testing with "doveadm auth lookup xyz@merlinux.eu"
auth_debug = no

!include auth-mailadm.conf.ext
```

/etc/dovecot/conf.d/10-mail.conf
```
namespace inbox {
  inbox = yes
}

mail_privileged_group = mail

protocol !indexer-worker {
}
```

/etc/dovecot/conf.d/10-ssl.conf
```
ssl = required

ssl_cert = </etc/letsencrypt/live/merlinux.eu/fullchain.pem
ssl_key = </etc/letsencrypt/live/merlinux.eu/privkey.pem

ssl_dh=</etc/dovecot/dh.pem

ssl_min_protocol = TLSv1.2
```

/etc/dovecot/conf.d/20-lmtp.conf
```
protocol lmtp {
  mail_plugins = $mail_plugins sieve
}
```
/etc/dovecot/conf.d/20-imap.conf
```
protocol imap {
  mail_plugins = $mail_plugins imap_quota imap_sieve
}
```
/etc/dovecot/conf.d/20-managesieve.conf
```
service managesieve-login {
  inet_listener sieve {
    port = 4190
  }
}
service managesieve {
  process_limit = 1024
}
protocol sieve {
}
```
/etc/dovecot/conf.d/90-sieve.conf
```
plugin {
  # sieve = file:~/sieve;active=~/.dovecot.sieve
  sieve_plugins = sieve_imapsieve sieve_extprograms
  sieve_before = /var/vmail/mail/sieve/global/spam-global.sieve
  sieve = file:/var/vmail/mail/sieve/%d/%n/scripts;active=/var/vmail/mail/sieve/%d/%n/active-script.sieve
  imapsieve_mailbox1_name = Spam
  imapsieve_mailbox1_causes = COPY
  imapsieve_mailbox1_before = file:/var/vmail/mail/sieve/global/report-spam.sieve
  imapsieve_mailbox2_name = *
  imapsieve_mailbox2_from = Spam
  imapsieve_mailbox2_causes = COPY
  imapsieve_mailbox2_before = file:/var/vmail/mail/sieve/global/report-ham.sieve
  sieve_pipe_bin_dir = /usr/bin
  sieve_global_extensions = +vnd.dovecot.pipe
}
```
Create a directory for our sieve scripts:
```
$ sudo mkdir -p /var/vmail/mail/sieve/global
```
/var/vmail/mail/sieve/global/spam-global.sieve
```
require ["fileinto","mailbox"];
if anyof(
    header :contains ["X-Spam-Flag"] "YES",
    header :contains ["X-Spam"] "Yes",
    header :contains ["Subject"] "*** SPAM ***"
    )
{
    fileinto :create "Spam";
    stop;
}
```
/var/vmail/mail/sieve/global/report-spam.sieve
```
require ["vnd.dovecot.pipe", "copy", "imapsieve"];
pipe :copy "rspamc" ["learn_spam"];
```
/var/vmail/mail/sieve/global/report-ham.sieve
```
require ["vnd.dovecot.pipe", "copy", "imapsieve"];
pipe :copy "rspamc" ["learn_ham"];
```
Compile sieve scripts and set the correct permissions:
```
$ sudo systemctl enable --now dovecot
$ sudo systemctl restart dovecot
$ sudo sievec /var/vmail/mail/sieve/global/spam-global.sieve
$ sudo sievec /var/vmail/mail/sieve/global/report-spam.sieve
$ sudo sievec /var/vmail/mail/sieve/global/report-ham.sieve
$ sudo chown -R vmail: /var/vmail/mail/sieve/
```

#### Postfix
```
$ sudo apt install postfix
```
Select internet site, when asked and enter the FQDN.

/etc/postfix/main.cf
```
smtpd_banner = $myhostname ESMTP $mail_name (Debian/GNU)
biff = no
append_dot_mydomain = no
readme_directory = no
compatibility_level = 2

# TLS parameters
smtpd_tls_cert_file = /etc/letsencrypt/live/merlinux.eu/fullchain.pem
smtpd_tls_key_file = /etc/letsencrypt/live/merlinux.eu/privkey.pem
smtpd_use_tls=yes
smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache
smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache

smtpd_relay_restrictions = permit_mynetworks permit_sasl_authenticated defer_unauth_destination
myhostname = merlinux.eu
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
myorigin = /etc/mailname
mydestination = localhost.localdomain, , localhost
relayhost = 
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
mailbox_size_limit = 0
recipient_delimiter = +
inet_interfaces = all
inet_protocols = all

smtpd_sender_login_maps = $virtual_mailbox_maps
local_recipient_maps = proxy:unix:passwd.byname
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_local_domain = 
smtpd_sasl_security_options =
broken_sasl_auth_clients = yes
smtpd_sasl_auth_enable = yes
smtpd_sender_restrictions = permit_mynetworks,reject_non_fqdn_sender,reject_unknown_sender_domain,reject_unlisted_sender,reject_sender_login_mismatch
smtpd_recipient_restrictions = permit_sasl_authenticated,permit_mynetworks,reject_unauth_destination
smtp_tls_security_level = may
smtpd_tls_security_level = may
smtp_tls_note_starttls_offer = yes
smtpd_tls_received_header = yes
milter_default_action = accept
milter_protocol   = 6
milter_mail_macros = i {mail_addr} {client_addr} {client_name} {auth_authen}
smtpd_milters     = inet:localhost:11334
non_smtpd_milters = inet:localhost:11334
virtual_mailbox_domains = merlinux.eu
virtual_transport = lmtp:unix:private/dovecot-lmtp
dovecot_destination_recipient_limit = 1
virtual_mailbox_base = /var/vmail
virtual_mailbox_maps = hash:/var/lib/mailadm/virtual_mailboxes
queue_directory = /var/spool/postfix

```

/etc/postfix/master.cf
```
# ==========================================================================
# service type  private unpriv  chroot  wakeup  maxproc command + args
#               (yes)   (yes)   (no)    (never) (100)
# ==========================================================================
smtp      inet  n       -       y       -       -       smtpd
#smtp      inet  n       -       y       -       1       postscreen
#smtpd     pass  -       -       y       -       -       smtpd
#dnsblog   unix  -       -       y       -       0       dnsblog
#tlsproxy  unix  -       -       y       -       0       tlsproxy
11025 inet n       -       y       -       -       smtpd
  -o syslog_name=postfix/11025
  -o smtpd_tls_wrappermode=yes
#  -o smtpd_sasl_auth_enable=yes
submission inet n       -       y       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_sasl_type=dovecot
  -o smtpd_tls_auth_only=yes
  -o smtpd_sasl_path=private/auth
  -o smtpd_reject_unlisted_recipient=no
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o smtpd_helo_restrictions=permit
  #-o smtpd_sender_restrictions=$mua_sender_restrictions
  #-o smtpd_recipient_restrictions=permit_sasl_authenticated,reject
  -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
  -o cleanup_service_name=sender-cleanup
smtps     inet  n       -       y       -       -       smtpd
  -o syslog_name=postfix/smtps
  -o smtpd_tls_wrappermode=yes
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_helo_restrictions=permit
  -o cleanup_service_name=sender-cleanup
#628       inet  n       -       y       -       -       qmqpd
pickup    unix  n       -       y       60      1       pickup
cleanup   unix  n       -       y       -       0       cleanup
sender-cleanup unix n   -       y       -       0       cleanup
  -o header_checks=regexp:/etc/postfix/header_checks_submission
qmgr      unix  n       -       n       300     1       qmgr
#qmgr     unix  n       -       n       300     1       oqmgr
tlsmgr    unix  -       -       y       1000?   1       tlsmgr
rewrite   unix  -       -       y       -       -       trivial-rewrite
bounce    unix  -       -       y       -       0       bounce
defer     unix  -       -       y       -       0       bounce
trace     unix  -       -       y       -       0       bounce
verify    unix  -       -       y       -       1       verify
flush     unix  n       -       y       1000?   0       flush
proxymap  unix  -       -       n       -       -       proxymap
proxywrite unix -       -       n       -       1       proxymap
smtp      unix  -       -       y       -       -       smtp
relay     unix  -       -       y       -       -       smtp
        -o syslog_name=postfix/$service_name
#       -o smtp_helo_timeout=5 -o smtp_connect_timeout=5
showq     unix  n       -       y       -       -       showq
error     unix  -       -       y       -       -       error
retry     unix  -       -       y       -       -       error
discard   unix  -       -       y       -       -       discard
local     unix  -       n       n       -       -       local
virtual   unix  -       n       n       -       -       virtual
lmtp      unix  -       -       y       -       -       lmtp
anvil     unix  -       -       y       -       1       anvil
scache    unix  -       -       y       -       1       scache
postlog   unix-dgram n  -       n       -       1       postlogd

maildrop  unix  -       n       n       -       -       pipe
  flags=DRhu user=vmail argv=/usr/bin/maildrop -d ${recipient}
uucp      unix  -       n       n       -       -       pipe
  flags=Fqhu user=uucp argv=uux -r -n -z -a$sender - $nexthop!rmail ($recipient)

ifmail    unix  -       n       n       -       -       pipe
  flags=F user=ftn argv=/usr/lib/ifmail/ifmail -r $nexthop ($recipient)
bsmtp     unix  -       n       n       -       -       pipe
  flags=Fq. user=bsmtp argv=/usr/lib/bsmtp/bsmtp -t$nexthop -f$sender $recipient
scalemail-backend unix	-	n	n	-	2	pipe
  flags=R user=scalemail argv=/usr/lib/scalemail/bin/scalemail-store ${nexthop} ${user} ${extension}
mailman   unix  -       n       n       -       -       pipe
  flags=FR user=list argv=/usr/lib/mailman/bin/postfix-to-mailman.py
  ${nexthop} ${user}

```
Now lets add a file:
/etc/postfix/header_checks_submission
```
/^Received: .*/ IGNORE
```
```
$ sudo systemctl restart postfix
$ sudo systemctl enable --now postfix
```

### Install Mailadm
[mailadm](https://mailadm.readthedocs.io/en/latest/#) is a simple commandline tool to manage our users. It will create and maintain the database that dovecot will use to deliver incoming or authenticate outgoing mail.
```
$ sudo apt install python3 python3-pip python3-venv
$ cd ~
$ git clone https://github.com/deltachat/mailadm
$ cd mailadm
$ vim install_mailadm.sh # Look at the script and edit the corresponding settings
```
Now review the installscript and change the enviroment variables. For example the `MAIL_DOMAIN=merlinux.eu` to your FQDN. As well as the `WEB_ENDPOINT` to your domain. And `VMAIL_HOME=/var/vmail` to the path we set our vmail user directory.
And then run it.
```
$ sudo bash install_mailadm.sh
```
Then run these commands and rerun the script:
```
$ sudo adduser mailadm vmail
$ sudo bash install_mailadm.sh
```
Add the mailadm executable to your PATH and set the database enviroment variable. These lines can be added to .profile:
```
$ export PATH=/var/lib/mailadm/venv/bin:$PATH
$ export MAILADM_DB=/var/lib/mailadm/mailadm.db
```
We should be able to create a token now. It will be valid for one day. You can also create tokens, that will be valid for longer periods.
```
$ sudo su mailadm
$ bash
$ source /var/lib/mailadm/venv/bin/activate
$ export PATH=/var/lib/mailadm/venv/bin:$PATH
$ export MAILADM_DB=/var/lib/mailadm/mailadm.db
$ mailadm add-token oneday --expiry 1d --prefix="test."
$ mailadm list-tokens
```
Now you should be able to generate a new user with the token you created.
Just try this in another shell:
```
$ curl -X POST https://merlinux.eu/new_email?t=1d<your token params>
```
This should return a burner email adress and the password valid for a defined time. You can now test if you can connect to your mail server with deltachat or any other mailclient. It should find the settings itself. You should also be able to send and recieve email.

### Setup Rspamd
Rspamd to will help us to check icoming mail for spam and have user sending limits for blocking spammers from our host. Let's add their ppa and install the newest version.
```
$ sudo apt install software-properties-common lsb-release redis-server wget
$ wget -O- https://rspamd.com/apt-stable/gpg.key | sudo apt-key add -
$ echo "deb http://rspamd.com/apt-stable/ $(lsb_release -cs) main" | sudo tee -a /etc/apt/sources.list.d/rspamd.list
$ sudo apt update
$ sudo apt install rspamd
```
Instead of modifying the stock config files, we will create new files in the /etc/rspamd/local.d/local.d/ directory, which will overwrite the default setting.

/etc/rspamd/local.d/worker-normal.inc
```
bind_socket = "127.0.0.1:11333";
```

/etc/rspamd/local.d/worker-proxy.inc
```
bind_socket = "127.0.0.1:11332";
milter = yes;
timeout = 120s;
upstream "local" {
  default = yes;
  self_scan = yes;
}
```
We need to set up a password for the controller worker, which provides access to the Rspamd web interface. To generate an encrypted password, run:
```
$ rspamadm pw --encrypt -p P4ssvv0rD 
$2$khz7u8nxgggsfay3qta7ousbnmi1skew$zdat4nsm7nd3ctmiigx9kjyo837hcjodn1bob5jaxt7xpkieoctb
```

/etc/rspamd/local.d/worker-controller.inc
```
password = "$2$khz7u8nxgggsfay3qta7ousbnmi1skew$zdat4nsm7nd3ctmiigx9kjyo837hcjodn1bob5jaxt7xpkieoctb";
```

We will use Redis as a back-end for Rspamd statistics:

/etc/rspamd/local.d/classifier-bayes.conf
```
servers = "127.0.0.1";
backend = "redis";
autolearn = true;
```
Set the milter headers:

/etc/rspamd/local.d/milter_headers.conf
```
use = ["x-spamd-bar", "x-spam-level", "authentication-results"];
global {
 use_dcc = no;
}
spamd {
 spamd_never_reject = yes;
 extended_spam_headers = yes;
 local_headers = ["x-spamd-bar"];
 authenticated_headers = ["authentication-results"];
 skip_local = false;
 skip_authenticated = true;
}
extended_spam_headers = true;
```
You can find more information about the milter headers [here](https://rspamd.com/doc/modules/milter_headers.html).

Let's add some whitelists for domains your users often communicate with. If the sender address has dkim, spf and dmarc records the chancew is higher, that it is actually the sender, you wanted to whitelist. You can read abourt whitelists [here](https://rspamd.com/doc/modules/whitelist.html).

/etc/rspamd/local.d/whitelist.conf
```
rules {
    WHITELIST_SPF = {
        valid_spf = true;
        domains = "$CONFDIR/local.d/whitelist_domains.map"; 
        score = -5.0;
    }

    WHITELIST_DKIM = {
        valid_dkim = true;
        domains = "$CONFDIR/local.d/whitelist_domains.map";
        score = -12.0;
    }

    WHITELIST_SPF_DKIM = {
        valid_spf = true;
        valid_dkim = true;
        domains = "$CONFDIR/local.d/whitelist_domains.map";
        score = -18.0;
    }

    WHITELIST_DMARC_DKIM = {
        valid_dkim = true;
        valid_dmarc = true;
        domains = "$CONFDIR/local.d/whitelist_domains.map";
        score = -27.0;
    }
}
```
You can later add important domains here.

/etc/rspamd/local.d/whitelist_domains.map
```
github.com
merlinux.eu
testrun.org
riseup.org
```
Let's also use the [replies](https://rspamd.com/doc/modules/replies.html) Module.

/etc/rspamd/local.d/replies.conf
```
action = "no action";
expire = 7d; # Expires after 7 days
key_prefix = "rr";
message = "Message is reply to one we originated";
symbol = "REPLY";
```
Finally, restart the Rspamd service:

```
$ sudo systemctl restart rspamd
```
#### Access the Rspamd Web-interface

You can now choose how you want to access the webinterface. There's two Methods. Either you make it publically available through nginx. Or you can later access it with ssh-tunneling.

To only access via ssh-tunneling skip this step.

/etc/nginx/sites-enabled/mailsetup
```
....
location /rspamdshdgfjsfgjdhgsfuzjguewzgguztgugztgugcmnbvbmn {
    proxy_pass http://127.0.0.1:11334/;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}
....
```
You should now be ablew to visit:
https://merlinux.eu/rspamdshdgfjsfgjdhgsfuzjguewzgguztgugztgugcmnbvbmn

Recommended:
To access rspamd with ssh-tunneling use this in a second shell on your local computer:
```
ssh -L 11334:localhost:11334 <youruser>@<yourserver>
```
And head to http://localhost:11334/ in your browser.

#### DKIM signing with Rspamd
DomainKeys Identified Mail (DKIM) is an email authentication method which adds a cryptographic signature to outbound message headers. It allows the receiver to verify that an email claiming to originate from a specific domain was indeed authorized by the owner of that domain. The main purpose of this is to prevent forged email messages. Let's create a new DKIM Keypair.
```
$ sudo mkdir /var/lib/rspamd/dkim/
$ sudo su
$ rspamadm dkim_keygen -b 2048 -s mail -k /var/lib/rspamd/dkim/mail.key > /var/lib/rspamd/dkim/mail.pub
$ exit
```
In the example above, we are using mail as a DKIM selector.
You should now have two new files in the /var/lib/rspamd/dkim/ directory, mail.key which is our private key file, and mail.pub, a file which contains the DKIM public key. We will update our DNS zone records later.
Set the correct ownership and permissions:
```
$ sudo chown -R _rspamd: /var/lib/rspamd/dkim 
$ sudo chmod 440 /var/lib/rspamd/dkim/*
```
Now we need to tell Rspamd where to look for the DKIM key, the selector name, and the last line, which will enable DKIM signing for alias sender addresses. To do that, create a new file with the following contents:
/etc/rspamd/local.d/dkim_signing.conf
```
selector = "mail";
path = "/var/lib/rspamd/dkim/$selector.key";
allow_username_mismatch = true;
```
Rspamd also supports signing for Authenticated Received Chain (ARC) signatures. You can find more information about the ARC specification [here](http://arc-spec.org/). Rspamd uses the DKIM module for dealing with ARC signatures, so we can simply copy the previous configuration:
```
$ sudo cp  /etc/rspamd/local.d/dkim_signing.conf /etc/rspamd/local.d/arc.conf
```
Restart the Rspamd service for changes to take effect.
```
$ sudo systemctl restart rspamd
```
#### DNS settings
We already created a DKIM key pair, and now we need to update our DNS zone. The DKIM public key is stored in the mail.pub file. 
```
$ sudo cat /var/lib/rspamd/dkim/mail.pub
```
The content of the file should look like this:
```
mail._domainkey IN TXT ( "v=DKIM1; k=rsa; "
        "p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAoE51Y+71GExkj3lWJN91ksKsWVt4omaDwuUmnjdGrPCQhoMnAWDa++sVA9B/n7xkfhW81TmMaLVBwz799HFQkVUNDmtrhrfij1mNv3UMP+U3oyGVwuVrmWL79C+2kPgRGPy7TB1Hasu28bW/WtJJIrJbTLgmQJGXR/eMjKds8zhWvLJ1ZbhHX1EZHc46xqBIP1xZ2WHOVOPOAR4e9"
        "gYo3BEdgYqxPZzT/gxJ2ODOGbys/Au/9K7e29BTAb5S7DQMAydhed241/I7oZx1Bw8nI9pZq0bp0mZjHm4i4Z5WyBiNCZH2rk6KhzDCwk7PI5HWAXW9FetAZSF7SZPGE+ge5wIDAQAB"
) ;
```
In most cases you can configure your DNS through a web interface. You need to create a new TXT record with mail._domainkey as a name, and for the value/content, you will need to remove the quotes and concatenate all three lines together.

In our case, the value/content of the TXT record should look like this:
```
v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAoE51Y+71GExkj3lWJN91ksKsWVt4omaDwuUmnjdGrPCQhoMnAWDa++sVA9B/n7xkfhW81TmMaLVBwz799HFQkVUNDmtrhrfij1mNv3UMP+U3oyGVwuVrmWL79C+2kPgRGPy7TB1Hasu28bW/WtJJIrJbTLgmQJGXR/eMjKds8zhWvLJ1ZbhHX1EZHc46xqBIP1xZ2WHOVOPOAR4e9gYo3BEdgYqxPZzT/gxJ2ODOGbys/Au/9K7e29BTAb5S7DQMAydhed241/I7oZx1Bw8nI9pZq0bp0mZjHm4i4Z5WyBiNCZH2rk6KhzDCwk7PI5HWAXW9FetAZSF7SZPGE+ge5wIDAQAB
```


### Setup OpenDKIM (Alternative to DKIM signing with rspamd)
We would recommend to use rspamd for dkim signing. If you have followed the guide up until here, you won't need this and you can skip this step.
```
$ sudo apt install opendkim opendkim-tools
```
Let's start with the main configuration file.
```
$ sudo vim /etc/opendkim.conf
```
```
AutoRestart             Yes
AutoRestartRate         10/1h
UMask                   002
Syslog                  yes
SyslogSuccess           Yes
LogWhy                  Yes

Canonicalization        relaxed/simple

ExternalIgnoreList      refile:/etc/opendkim/TrustedHosts
InternalHosts           refile:/etc/opendkim/TrustedHosts
KeyTable                refile:/etc/opendkim/KeyTable
SigningTable            refile:/etc/opendkim/SigningTable

Mode                    sv
PidFile                 /var/run/opendkim/opendkim.pid
SignatureAlgorithm      rsa-sha256

UserID                  opendkim:opendkim

Socket                  inet:11025@localhost

```
```
$ sudo vim /etc/default/opendkim
```
Add the following line:
```
SOCKET="inet:11025@localhost"
```
Configure postfix to use the milter:
```
$ sudo vim /etc/postfix/main.cf
```
```
milter_protocol = 6
milter_default_action = accept

smtpd_milters = inet:localhost:11025
non_smtpd_milters = inet:localhost:11025
```
Create some directories
```
$ sudo mkdir /etc/opendkim
$ sudo mkdir /etc/opendkim/keys
```
Add trusted hosts.
```
$ sudo vim /etc/opendkim/TrustedHosts
```
```
127.0.0.1
localhost
::1

*.merlinux.eu

#*.example.net
```
Create a key table:
```
$ sudo vim /etc/opendkim/KeyTable
```
```
mail._domainkey merlinux.eu:mail:/etc/opendkim/keys/merlinux.eu/mail.private
```
Create a signing table:
```
$ sudo vim /etc/opendkim/SigningTable
```
```
*@merlinux.eu mail._domainkey
```
Generate keys:
```
$ cd /etc/opendkim/keys
$ sudo mkdir merlinux.eu
$ cd merlinux.eu
```
```
$ sudo opendkim-genkey -s mail -d merlinux.eu
$ sudo chown opendkim:opendkim mail.private
```
Now /etc/opendkim/keys/merlinux.eu/mail.txt should contain our public DKIM key. Now let's add it to our DNS entries:
```
Name: mail._domainkey

Text: "v=DKIM1; k=rsa; p=............................................................."
```
Now restart postfix and opendkim:
```
$ sudo service postfix restart
$ sudo service opendkim start
$ sudo service opendkim restart
```

### Setup DMARC
Check if you got it right by sending an empty email to:
check-auth@verifier.port25.com
They will reply you with results.

Or write an email to a gmail/yahoo/gmx account under your control and look into the header. It should show you something like: dkim=pass.

If everything works sofar, we can add the dmarc record to our dns entries.
Which will tell other mailservers only to accept mail from our destination,
when the dkim signature is correct. This is required by big mailproviders like
google yahoo and so on to prevent spoofing.  Just replace your@email.com by an
email adress of yours (Not any on the your new mailserver, or you will not be
notified when mails bounce because of failing dkim checks).

```
Name: _dmarc

Text: "v=DMARC1; p=reject; rua=mailto:your@otheremail.com; ruf=mailto:your@otheremail.com; adkim=r; aspf=r; rf=afrf"
```
Now you should be able to write emails to gmail/yahoo/gmx!

## Congratulations you successfully configured a mailserver!

You can now test your setup and connect [deltachat](http://get.delta.chat/) to
your new mailserver.

## Secure SSH Access

Author: missytake@systemli.org

On 2021-04-23, we realized that SSH was not protected after the best practices.
So I installed sshguard with `sudo apt install sshguard`. The default config
seemed fine, so I didn't touch anything.

## Mailreports

we decided to try pflogsumm on testrun. So i added an alias.

```
$ vim /etc/postfix/virtual
$ postmap /etc/postfix/virtual
```