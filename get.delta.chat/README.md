# get.delta.chat

Author: compl4xx@systemli.org  
If you have questions, ask me.

get.delta.chat is a landing page for people who want to download a Delta Chat
client as easily as possible. The site is running on the page VM at
greenhost.nl; see the [delta.chat setup
documentation](https://github.com/deltachat/sysadmin/tree/master/delta.chat)
for how I set up the VM.

## Setup

### DNS

First I created a DNS entry for get.delta.chat at Hetzner, our DNS provider:

```
get                      IN A       37.218.242.41
```

Shortly after, it started working.

### Setting up NGINX

For nginx, I copied the delta.chat config and adjusted it. A copy of it is in
this repository. These were my steps:

```
sudo mkdir -p /var/www/html/get
sudo cp /etc/nginx/sites-available/delta.chat /etc/nginx/sites-available/get.delta.chat
sudo vim /etc/nginx/sites-available/get.delta.chat
sudo ln -rs /etc/nginx/sites-available/get.delta.chat /etc/nginx/sites-enabled/get.delta.chat
```

Later I also added a redirect rule; if a page isn't found (404), the user gets
redirected to https://delta.chat instead.

### Let's Encrypt

After the nginx config was adjusted from delta.chat to get.delta.chat, I ran
certbot to create TLS certificates and adjust the nginx config for them
automatically:

```
sudo certbot --nginx
sudo etckeeper commit "enable get.delta.chat, let's encrypt"
```

I chose 3 for "get.delta.chat" and 2 for "redirect http to https".

### Enable pushing for the jekyll user

To enable the jekyll user to scp files to this website, I executed this
command:

```
sudo chown jekyll:jekyll /var/www/html/get -R
```

This way, we can push updates to this page automatically with GitHub actions.
The private key is deposited in the github secrets of the deltachat-desktop and
deltachat-pages repositories. You can also find it in our git-crypt vault in
the OTF repository.

