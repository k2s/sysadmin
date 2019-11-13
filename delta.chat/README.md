# Setup page VM for delta.chat & download.delta.chat

For questions: [compl4xx@testrun.org](mailto:compl4xx@testrun.org)

This is how I set up the VM for delta.chat & the download page. The reasons
were to migrate away from netlify, and to have a download space where we can
push deliverables in automated release scripts.

## Create the VPS

The VPS is running at greenhost.nl. I selected the following parameters during
VPS creation:

* 2 GB Ram
* 1 CPU
* 200 GB Disk Space
* Location: Amsterdam
* OS only: Debian 9 (stretch)
* SSH key: emil
* Hostname: page
* Advanced options: enable API (not sure whether we need it)

It told me to login with `ssh root@37.218.242.41`.

## Setting up Users

I first executed `apt update && apt upgrade -y` to bring the server up-to-date.
Then I installed vim and man.

I created an `emil` user and added it to the `sudo` group.

When I played around with sudo, it always gave me the following error: `sudo:
unable to resolve host page`. Because that was odd, I added the following line
to `/etc/hosts`:

```
127.0.1.1	page
```

The error stopped appearing afterwards.

### Passwordless sudo

Later (2019-11-13), I configured sudo so that users in the sudo group don't
need a password anymore. I committed it to etckeeper.

## SSH config

First I copied `/root/.ssh/authorized_keys` to
`/home/emil/.ssh/authorized_keys`, and tested it, to make sure I could login as
the emil user.

Then I edited the SSH config to forbid root login, change the port to 42022,
and forbid password login, to secure the server.

But when I tested it, I received a connection timeout for port 42022. I set it
back to 22, and it worked again; the login message told me that the firewall
only allows the ports 22, 80, and 443. Fine, then we'll just use the normal
port, I guess. At least the usernames aren't as easy to guess, and root is
forbidden.

A copy of the `/etc/ssh/sshd_config` file is in this repository.

## Further Server Configuration

Sources:
* https://github.com/codespeaknet/sysadmin/blob/master/docs/notes.rst

Now I installed etckeeper, to keep track of changes in the server
configuration.  (If you change something in the /etc directory, please run
etckeeper commit "$message" afterwards.)

```
sudo apt update
sudo apt install etckeeper
echo "*-" >> /etc/.gitignore
```

Also, two other basics:

```
sudo apt install unattended-upgrades
sudo update-alternatives --config editor  # choose vim
sudo etckeeper commit "vim as default editor"
```

## Setting up nginx + jekyll

### Let's Encrypt

Sources:
* https://certbot.eff.org/lets-encrypt/debianstretch-nginx
* https://hynek.me/articles/hardening-your-web-servers-ssl-ciphers/

To set up Let's Encrypt with certbot, There first needs to be a running nginx:

```
sudo apt install -y nginx
```

That's it. Now we can install certbot and let it take care of the TLS
configuration etc.:

```
sudo sh -c 'echo "deb http://deb.debian.org/debian stretch-backports main" > /etc/apt/sources.list.d/certbot.list'
sudo apt update
sudo apt-get install certbot python-certbot-nginx -t stretch-backports
sudo certbot --nginx
```

The last command asks some questions. I answered them like this:

```
$ sudo certbot --nginx
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Plugins selected: Authenticator nginx, Installer nginx
Enter email address (used for urgent renewal and security notices) (Enter 'c' to
cancel): compl4xx@testrun.org

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Please read the Terms of Service at
https://letsencrypt.org/documents/LE-SA-v1.2-November-15-2017.pdf. You must
agree in order to register with the ACME server at
https://acme-v02.api.letsencrypt.org/directory
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
(A)gree/(C)ancel: A

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Would you be willing to share your email address with the Electronic Frontier
Foundation, a founding partner of the Let's Encrypt project and the non-profit
organization that develops Certbot? We'd like to send you email about our work
encrypting the web, EFF news, campaigns, and ways to support digital freedom.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
(Y)es/(N)o: N
No names were found in your configuration files. Please enter in your domain
name(s) (comma and/or space separated)  (Enter 'c' to cancel): c         
Please specify --domains, or --installer that will help in domain names autodiscovery, or --cert-name for an existing certificate name.

IMPORTANT NOTES:
 - Your account credentials have been saved in your Certbot
   configuration directory at /etc/letsencrypt. You should make a
   secure backup of this folder now. This configuration directory will
   also contain certificates and private keys obtained by Certbot so
   making regular backups of this folder is ideal.
```

In the mid of it I realized that of course delta.chat is not yet pointing to
the server, so the Let's Encrypt ACME handshake can't work.  So I cancelled it
and chose to proceed with the jekyll setup first, so we can do the Let's
Encrypt handshake when we want to migrate completely.

### Jekyll

Sources:
* http://briancain.net/using-jekyll-and-nginx/
* https://github.com/deltachat/provider-db/blob/master/.github/workflows/jekyll.yml

For the jekyll setup, we need to configure the deltachat-pages repository so it
builds the html pages in a docker container, and copies them to the
`/var/www/html` directory on the server, which is served to the outside by
nginx.

So first I added a new user `jekyll` for GitHub to login, without sudo, but
push rights to `/var/www/html`. I saved the password to my personal password
manager.

```
sudo adduser jekyll
sudo chown root:jekyll /var/www/html/
sudo chmod 775 /var/www/html
```

Then I generated a SSH key for jekyll on my local machine.  I also added the
SSH key of jekyll to `/home/jekyll/.ssh/authorized_keys`, so GitHub can login
there.

Afterwards I created the two CI scripts in
https://github.com/deltachat/deltachat-pages/pull/188, and added the jekyll
username and its private SSH key to the github secrets of the deltachat-pages
repository. This way the CI scripts can access them.

As I know restarted the tests, the site was available at
`http://37.218.242.41/_site/en/` - a huge success :)

Most of the links were broken first though. I had to make some changes to
`/etc/nginx/sites-enabled/default` to fix them. Afterwards I renamed the config
file to delta.chat and linked to it from `/etc/nginx/sites-enabled/` to make it
active. A copy of the file is in this repository as well.

### Download directory

So I created the `/var/www/html/download/android/` directory, and used wget to
get the latest gplay apk release there. The goal was to get this link working:
http://download.delta.chat/android/deltachat-gplay-release-0.930.2.apk

```
sudo mkdir -p /var/www/html/download/android
sudo mkdir -p /var/www/html/download/desktop
sudo mkdir -p /var/www/html/download/ios
sudo chown jekyll:jekyll /var/www/html/download -R
cd /var/www/html/download/android
sudo wget https://github.com/deltachat/deltachat-android/releases/download/preview-v0.930.2/deltachat-gplay-release-0.930.2.apk
```

Then I created a new nginx config file in `/etc/nginx/sites-available/`,
download.delta.chat, and configured it to listen to the URL
download.delta.chat. It is supposed to return a file, if it exists, and
redirect to https://delta.chat/en/download, if there is no file.

I linked to it from `/etc/nginx/sites-enabled/` to activate it, and reloaded
nginx:

```
sudo ln -rs /etc/nginx/sites-available/download.delta.chat /etc/nginx/sites-enabled/download.delta.chat
sudo service nginx reload
```

The new config file is in this repository, too.

In the end I added a DNS entry to netlify.com, to make download.delta.chat
available from the internet:

```
A	download	3600	37.218.242.41
```

The link works now, so great :) 

### DNS Problems With Netlify

So finally the point came to change DNS and do Let's Encrypt.
First I wanted to create the following DNS entry:

```
A	@	180	37.218.242.41
```

Problem: Netlify doesn't let you delete certain DNS entry, and this one was
conflicting with a non-deletable one. I decided to come back later, and first
do Let's Encrypt for download.delta.chat.

### Let's Encrypt for download.delta.chat

Setting up Let's Encrypt for download.delta.chat was super easy, basically just
one command at this point:

```
$ sudo certbot --nginx
[sudo] password for emil: 
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Plugins selected: Authenticator nginx, Installer nginx

Which names would you like to activate HTTPS for?
 
1: delta.chat
2: download.delta.chat

Select the appropriate numbers separated by commas and/or spaces, or leave input
blank to select all options shown (Enter 'c' to cancel): 2
Obtaining a new certificate
Performing the following challenges:
http-01 challenge for download.delta.chat
Waiting for verification...
Cleaning up challenges
Deploying Certificate to VirtualHost /etc/nginx/sites-enabled/download.delta.chat

Please choose whether or not to redirect HTTP traffic to HTTPS, removing HTTP access.
 
1: No redirect - Make no further changes to the webserver configuration.
2: Redirect - Make all requests redirect to secure HTTPS access. Choose this for
new sites, or if you're confident your site works on HTTPS. You can undo this
change by editing your web server's configuration.
 
Select the appropriate number [1-2] then [enter] (press 'c' to cancel): 2
Redirecting all traffic on port 80 to ssl in /etc/nginx/sites-enabled/download.delta.chat


Congratulations! You have successfully enabled https://download.delta.chat

You should test your configuration at:
https://www.ssllabs.com/ssltest/analyze.html?d=download.delta.chat


IMPORTANT NOTES:
 - Congratulations! Your certificate and chain have been saved at:
   /etc/letsencrypt/live/download.delta.chat/fullchain.pem
   Your key file has been saved at:
   /etc/letsencrypt/live/download.delta.chat/privkey.pem
   Your cert will expire on 2020-01-21. To obtain a new or tweaked
   version of this certificate in the future, simply run certbot again
   with the "certonly" option. To non-interactively renew *all* of
   your certificates, run "certbot renew"
 - If you like Certbot, please consider supporting our work by:

   Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
   Donating to EFF:                    https://eff.org/donate-le
```

### Hardening Login Security of jekyll

Source: https://serverfault.com/a/83857

When we configured the GitHub actions to push, we had to give the private key
of jekyll to GitHub (as a GitHub secret). It's only accessible for members of
the deltachat GitHub organization, and for GitHub of course. So I decided we
had to limit access of the key to scp, with the rssh tool.

I set it up like this:

```
sudo apt install rssh
sudo chsh -s /usr/bin/rssh jekyll
cd /home/jekyll
sudo chmod u-w * -R
sudo chmod u-w .* -R
sudo vim /etc/rssh.conf
```

In the config file, I basically only uncommented `allowscp`.  I committed it to
etckeeper, but a copy is also in this repository.

#### Allowing rsync

Later we realized we also wanted to copy symlinks, so we could make a link for
stable releases. This is only possible with rsync, not with scp. So I also
allowed rsync in the rssh config.

### Changing DNS of delta.chat

To change the DNS entry of delta.chat to 37.218.242.41, we first needed to
migrate our DNS servers away from netlify, towards Hetzner.

to do: describe migration

### Let's Encrypt for delta.chat 2nd try

So I tried again to ask for a delta.chat Let's Encrypt cert:

```
$ sudo certbot --nginx
[sudo] password for emil: 
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Plugins selected: Authenticator nginx, Installer nginx

Which names would you like to activate HTTPS for?

1: delta.chat
2: download.delta.chat

Select the appropriate numbers separated by commas and/or spaces, or leave input
blank to select all options shown (Enter 'c' to cancel): 1
Obtaining a new certificate
Performing the following challenges:
http-01 challenge for delta.chat
Waiting for verification...
Cleaning up challenges
Failed authorization procedure. delta.chat (http-01): urn:ietf:params:acme:error:unauthorized :: The client lacks sufficient authorization :: Invalid response from https://delta.chat/.well-known/acme-challenge/LYgfZRe-pDpWCD9CBAX2wB0PMmDlKZQrTF7ItkNO0x8 [104.198.14.52]: "<!DOCTYPE html>\n<html>\n\n<head>\n<title>Page not found - Delta Chat</title>\n<meta charset=\"UTF-8\" />\n<meta name=\"viewport\" content"

IMPORTANT NOTES:
 - The following errors were reported by the server:

   Domain: delta.chat
   Type:   unauthorized
   Detail: Invalid response from
   https://delta.chat/.well-known/acme-challenge/LYgfZRe-pDpWCD9CBAX2wB0PMmDlKZQrTF7ItkNO0x8
   [104.198.14.52]: "<!DOCTYPE html>\n<html>\n\n<head>\n<title>Page
   not found - Delta Chat</title>\n<meta charset=\"UTF-8\" />\n<meta
   name=\"viewport\" content"

   To fix these errors, please make sure that your domain name was
   entered correctly and the DNS A/AAAA record(s) for that domain
   contain(s) the right IP address.
```

Apparently delta.chat still pointed to 104.198.14.52, the old ip. Probably the
minimum TTL of 3600 was responsible for that. I didn't have a whole hour time
to wait for this, so I changed the IP back to 104.198.14.52 in the Hetzner DNS
settings and decided to try again another time.

The next day I tried again:

```
$ sudo certbot --nginx
[sudo] password for emil: 
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Plugins selected: Authenticator nginx, Installer nginx

Which names would you like to activate HTTPS for?
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
1: delta.chat
2: download.delta.chat
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Select the appropriate numbers separated by commas and/or spaces, or leave input
blank to select all options shown (Enter 'c' to cancel): 1
Obtaining a new certificate
Performing the following challenges:
http-01 challenge for delta.chat
Waiting for verification...
Cleaning up challenges
Deploying Certificate to VirtualHost /etc/nginx/sites-enabled/delta.chat

Please choose whether or not to redirect HTTP traffic to HTTPS, removing HTTP access.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
1: No redirect - Make no further changes to the webserver configuration.
2: Redirect - Make all requests redirect to secure HTTPS access. Choose this for
new sites, or if you're confident your site works on HTTPS. You can undo this
change by editing your web server's configuration.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Select the appropriate number [1-2] then [enter] (press 'c' to cancel): 2
Redirecting all traffic on port 80 to ssl in /etc/nginx/sites-enabled/delta.chat

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Congratulations! You have successfully enabled https://delta.chat

You should test your configuration at:
https://www.ssllabs.com/ssltest/analyze.html?d=delta.chat
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

IMPORTANT NOTES:
 - Congratulations! Your certificate and chain have been saved at:
   /etc/letsencrypt/live/delta.chat/fullchain.pem
   Your key file has been saved at:
   /etc/letsencrypt/live/delta.chat/privkey.pem
   Your cert will expire on 2020-01-30. To obtain a new or tweaked
   version of this certificate in the future, simply run certbot again
   with the "certonly" option. To non-interactively renew *all* of
   your certificates, run "certbot renew"
 - If you like Certbot, please consider supporting our work by:

   Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
   Donating to EFF:                    https://eff.org/donate-le

```

This time it worked! https://delta.chat resolved well and showed the usual
delta.chat website.

### Subdomains: www & master

Now I only had to point the CNAME records for www and master to `delta.chat.`,
to get rid of netlify completely:

```
master               180 IN CNAME   delta.chat.
www                  180 IN CNAME   delta.chat.
```

#### Let's Encrypt for www and master

After that, I also had to add Let's Encrypt certificates for www and master. So
I copied the default nginx configuration for delta.chat to www and master, and
enabled it:

```
emil@page:/etc/nginx/sites-available$ sudo cp delta.chat www.delta.chat
emil@page:/etc/nginx/sites-available$ sudo cp delta.chat master.delta.chat
emil@page:/etc/nginx/sites-available$ sudo ln -rs /etc/nginx/sites-available/www.delta.chat /etc/nginx/sites-enabled/www.delta.chat
emil@page:/etc/nginx/sites-available$ sudo ln -rs /etc/nginx/sites-available/master.delta.chat /etc/nginx/sites-enabled/master.delta.chat
```

After that, `sudo service nginx reload` threw an error: `nginx: [emerg] a
duplicate default server for 0.0.0.0:80 in
/etc/nginx/sites-enabled/master.delta.chat:106`.  So I adjusted the nginx
configuration of master and www, so there was only one default_server,
delta.chat.

After reloading nginx, I could install Let's Encrypt certificates for them as
well.

I committed the changes to etckeeper. The nginx configs are in this repository.

#### Adding former netlify redirects

On 2019-11-13 we realized that the old redirects from
https://github.com/deltachat/deltachat-pages/blob/d4034e0c65dfcbc2a54e07975857fe91939d6d07/_redirects
which worked under netlify didn't work anymore. So I added them to the nginx
config of delta.chat, reloaded the nginx server, and committed it to etckeeper.

## That's it!

So now delta.chat is hosted at greenhost.nl.

The preview links seem to work mostly fine, but if you want to click on the
blogposts, you only get a link to the blogposts deployed on production. The
workaround is to paste the commit sha into the URL.


