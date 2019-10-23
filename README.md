# Setup page VM for delta.chat & download.delta.chat

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
`/etc/nginx/sites-enabled/default` to fix them. A copy of the file is in this
repository as well.


