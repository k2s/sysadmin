# js.delta.chat

Date: 2020-02-25  
Author: missytake@systemli.org

Until today, js.delta.chat was just a redirect to
https://github.com/deltachat/deltachat-node#deltachat-node. Then treefit
[introduced typedoc](https://github.com/deltachat/deltachat-node/pull/426/files) 
for the deltachat-node documentation, and we created a dedicated page 
for https://js.delta.chat.

## DNS

First I changed the DNS settings to point to the pages server, from

```
js                       IN A       78.47.150.134
```

to 

```
js                       IN A       37.218.242.41
js                       IN AAAA    2a00:c6c0:0:151:5::41
```

## Server Setup

For the setup of the server in general, see https://github.com/deltachat/sysadmin/tree/master/delta.chat

### Creating folders

First I created the upload folder and created a fitting user:

```
cd /var/www/html/
sudo mkdir js
sudo chown jekyll:jekyll -R js/
```

### Setting up NGINX

I copied over a similar nginx config, adjusted it to my needs, and activated it:

```
sudo cp bots.delta.chat js.delta.chat
sudo vim js.delta.chat
sudo ln -s /etc/nginx/sites-available/js.delta.chat /etc/nginx/sites-enabled/js.delta.chat
sudo service nginx reload
```

I used the TLS certificate from bots.delta.chat first - otherwise, nginx
wouldn't accept the config.

### Let's Encrypt

Now I could generate the Let's Encrypt certificate:

```
sudo certbot --nginx
# options I chose:
# 7: js.delta.chat
# 2: Redirect
```

After that, https://js.delta.chat worked, and showed a beautiful 403 error.

Now I could commit the changes to etckeeper and copy the NGINX config to this
repository.

## Creating the GitHub Action for Automated Pushing

On top of treefit's branch in
https://github.com/deltachat/deltachat-node/pull/426, [this
PR](https://github.com/deltachat/deltachat-node/pull/427) helped to complete
his GitHub workflow.

I added the jekyll username & its private key to the GitHub secrets in
https://github.com/deltachat/deltachat-node - after that, the action was able
to upload the contents to https://js.delta.chat, and it showed actual content.

