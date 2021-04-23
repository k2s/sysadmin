# merlinux.eu (hq6)
merlinux.eu specifically was set up as the business email server for merlinux GmbH by Janek. It's a 1-core VM hosted at Hetzner. In addition to the following guide, which was created as a "clean" mailserver setup for hq6 and dubby, we installed rspamd on hq6.

## How to setup a Mailserver for Deltachat with Dovecot and Postfix (hq6 and dubby)
This should be an example how to setup a very minimalistic Mailserver for use with DeltaChat. We will use [mailadm](https://github.com/deltachat/mailadm) to manage mail accounts and create qr-join codes.

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
```
$ sudo apt update && sudo apt full-upgrade
$ sudo apt install etckeeper vim
$ sudo vim /etc/etckeeper/etckeeper.conf
$ git config --global user.name "User"
$ git config --global user.email "Email"
$ git config --global core.editor "vim"
$ sudo etckeeper init
$ sudo etckeeper commit "init"
```

### Setup Users
```
$ sudo apt install sudo
$ sudo adduser <your-user>
$ sudo adduser <your-user> sudo

$ sudo useradd --create-home --home-dir /var/vmail --user-group --shell /usr/sbin/nologin vmail
$ sudo chown -R vmail /var/vmail
$ sudo chgrp -R vmail /var/vmail
$ sudo chmod -R 770 /var/vmail
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
$ sudo apt install ufw nginx git unattended-upgrades

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
$ sudo apt install dovecot-common dovecot-imapd dovecot-lmtpd dovecot-sqlite
```
Generate Diffie-Hellman Key (this can take a while)
```
$ sudo su
$ openssl dhparam 4096 > dh.pem
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

service submission {
 = 1024
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
```
$ sudo systemctl restart dovecot
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
smtp_tls_security_level = encrypt
smtpd_tls_security_level = encrypt
smtp_tls_note_starttls_offer = yes
smtpd_tls_received_header = yes
milter_default_action = accept
milter_protocol   = 6
smtpd_milters     = inet:localhost:12201
non_smtpd_milters = inet:localhost:12201
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
```

### Install Mailadm
[mailadm docs](https://mailadm.readthedocs.io/en/latest/#)
```
$ sudo apt install python3 python3-pip python3-venv
$ cd ~
$ git clone https://github.com/deltachat/mailadm
$ cd mailadm
$ vim install_mailadm.sh
$ adduser mailadm vmail
$ sudo chgrp vmail ~mailadm
```
Now review the installscript and change the enviroment variables. For example the `MAIL_DOMAIN=merlinux.eu` to your FQDN. As well as the `WEB_ENDPOINT`.
And then run it.
```
$ sudo bash install_mailadm.sh
```
If the script should fail at the installation. You can try to install mailadm in the venv yourself and run the script again.
#### THIS MAY NOT BE NECESSARY:
```
$ sudo su root
$ python3 -m venv /var/lib/mailadm/venv
$ /var/lib/mailadm/venv/bin/pip install -U .
$ exit
$ sudo bash install_mailadm.sh
```
If the script finishes by creating symlinks and restarting services, you can continue.
Add the mailadm executable to your PATH and set the database enviroment variable:
```
$ export PATH=~mailadm/venv/bin:$PATH
$ export MAILADM_DB=/var/lib/mailadm/mailadm.db
```
And set some permissions
```
$ sudo chmod 777 /var/lib/mailadm/mailadm.db
$ sudo chmod 777 /var/lib/mailadm
$ sudo chmod 777 /var/lib/mailadm/virtual_mailboxes.db
$ sudo chmod 777 /var/lib/mailadm/virtual_mailboxes
```
We should be able to create a token now. It will be valid for one day. You can also create tokens, that will be valid for longer periods.
```
$ mailadm add-token oneday --expiry 1d --prefix="test."
$ mailadm list-tokens
```
Now you should be able to generate a new user with the token you created.
Just try this in another shell:
```
$ curl -X POST https://merlinux.eu/new_email?t=1d<your token params>
```
This should return a burner email adress and the password.


### Setup OpenDKIM
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
Check if you got it right by sending an empty email to:
check-auth@verifier.port25.com
Or write an email to a gmail/yahoo/gmx account under your control and look into the header. It should show you something like: dkim=pass.
[opendkim guide](https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-dkim-with-postfix-on-debian-wheezy)

(/etc/postfix/header_checks_submission file !?!?!)

### Setup DMARC
If everything works sofar, we can add the dmarc record to our dns entries. Which will tell other mailservers only to accept mail from our destination, when the dkim signature is correct. This is required by big mailproviders like google yahoo and so on to prevent spoofing.
Just replace your@email.com by an email adress of yours (Not any on the your new mailserver, or you will not be notified when mails bounce because of failing dkim checks).
```
Name: _dmarc

Text: "v=DMARC1; p=reject; rua=mailto:your@email.com; ruf=mailto:your@email.com; adkim=r; aspf=r; rf=afrf"
```
Now you should be able to write emails to gmail/yahoo/gmx!

## Congratulations you successfully configured a mailserver!
You can now test your setup and connect [deltachat](http://get.delta.chat/) to your new mailserver.

## Secure SSH Access

Author: missytake@systemli.org

On 2021-04-23, we realized that SSH was not protected after the best practices.
So I installed sshguard with `sudo apt install sshguard`. The default config
seemed fine, so I didn't touch anything.

