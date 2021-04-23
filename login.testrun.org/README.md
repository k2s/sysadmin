# login.testrun.org

Author: missytake@systemli.org

pabz, treefit and I set up login.testrun.org to hack together a
login-with-deltachat reference implementation for support.delta.chat login.

## Setup

I created the cheapest possible VPS at portal.eclips.is and added my SSH key to
the root account.

First I set up the missytake user, added it to sudo, and made sudo passwordless.

Then I configured the following DNS entry:

```
login                    IN A       37.218.242.162
```

### Installing nvm, node.js, etc.

First I installed some tools for building, but also for convenience:

```
sudo apt install git vim build-essential curl
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.1/install.sh | bash
nvm install node
npm i forever -g
```

The I cloned the login-demo repository to set up the login.testrun.org website:

```
git clone https://github.com/deltachat/login-demo
cd login-demo
git checkout delta-oauth
npm i 
```

The server needs some credentials as well, I put them into
`/home/missytake/.login-dcrc`. You can find them in the secrets folder in our
git-crypt repository. The format needs to look like this:

```
{
    "email_address": "bot@example.org",
    "email_password": "password",
    "client": {
        "clientId": "xxxxxxxxxxxxxxxxxxxxxxxxxxxx",
        "clientSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
        "redirectUris": ["https://support.delta.chat/auth/oauth2_basic/callback"]
    }
}
```

Then we started the process with `npm start` played around with it for a while,
and pulled new changes a couple of times.

### Setup NGINX & Let's Encrypt

At some point we wanted to setup the website correctly, so I installed nginx
and created a `proxy_pass` rule to pass the https traffic to port 3000, where
the login-demo was running: 

```
sudo mv /etc/nginx/sites-available/default /etc/nginx/sites-available/login.testrun.org
sudo vim /etc/nginx/sites-available/login.testrun.org
sudo ln -s /etc/nginx/sites-available/login.testrun.org /etc/nginx/sites-enabled/login.testrun.org
sudo service nginx restart
```

Now, to add Let's Encrypt for working https, I installed certbox and executed
it:

```
sudo apt-get install certbot python-certbot-nginx
sudo certbot --nginx
```

### Keep the service running

Our oauth2 login server ran with `npm start`, but for it to keep running even
when you log out of the SSH shell, you can use `forever start
~/login-demo/src/main.js`. 

To show running processes, use `forever list`, and to restart the running
process, look out for the pid, and execute `forever restart $pid`.

Now it already showed our main page with the QR code, but this was not the
final version - we also wanted to be able to connect it to discourse, so we
installed the oauth2-basic plugin into support.delta.chat and connected it to
it. (Details in the [forum docs](../support.delta.chat/README.md)).

When it worked, we checked out the master branch, rebuilt it, and restarted the
process:

```
git checkout master
npm i
forever restart $(pgrep node -n)
```

### Avoid full disks

The server only has 5GB disk space, so the disk running full is quite likely.
If that happens and the server stops working, you can delete this 300MB large
file: `/home/missytake/delete-me-if-disk-space-is-low`.

I created it with `fallocate -l 300M delete-me-if-disk-space-is-low`; maybe
recreate it after you fixed the issue (e.g. by cleaning up the database, `sudo
apt autoremove`, or allocating more disk space to the VPS).

### Refactoring Branch

For https://github.com/deltachat/login-demo/pull/2 we needed to install rust.
So I did `sudo apt install cargo` and reran the service.

The compiler still failed, because the stable release of cargo isn't allowed to
do some of the packages we apparently needed.

So I ran:

```
sudo apt remove cargo
sudo apt autoremove
curl -sf -L https://static.rust-lang.org/rustup.sh | sh
```

The script asked me several installation options. As we needed the nightly
installer, I modified it:

```
   default host triple: x86_64-unknown-linux-gnu
     default toolchain: nightly
               profile: default
  modify PATH variable: yes
```

This didn't work yet, I had to re-add the toolchain to cargo: `rustup toolchain
install nightly-2019-08-13-x86_64-unknown-linux-gnu` and rebuild the service
with npm i.

Then pabz did some magic and changed the project so it takes much less build
space. Now it works fine again.

## Installing Unattended Upgrades

On 2019-12-12, I installed unattended-upgrades, so the server is kept up to
date with the latest Debian upgrades automatically.

```
sudo apt update
sudo apt install -y unattended-upgrades apt-listchanges
```

I configured it to send mail reports to me daily:

```
sudo sh -c "echo 'Unattended-Upgrade::Mail "root";' >> /etc/apt/apt.conf.d/50unattended-upgrades"
sudo sh -c 'echo "root: missytake@systemli.org" >> /etc/aliases'
sudo sh -c "echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections"
sudo dpkg-reconfigure -f noninteractive unattended-upgrades
sudo service unattended-upgrades restart
```

Then I wanted to commit these changes to etckeeper, when I realized, that we
didn't have etckeeper on the machine. Yet.

## Installing etckeeper

This was easy:

```
sudo apt update
sudo apt install -y etckeeper
sudo sh -c 'echo "*-" >> /etc/.gitignore'
```

## Installing discourse-login-bot instead of login-demo

On 2020-03-17, the https://github.com/deltachat-bot/discourse-login-bot
repository was far enough that we could deploy it. **Note:** During this, I
forgot to copy the database (`~/login-demo/data/db.sqlite`)as well - it turns out that this is very bad. If
you ever try to repeat these steps, please remember to copy the existing
database as well for a complete migration.

First I stopped the running login-demo service with `forever stop $(pgrep node -n)`.

Then I cloned the github repository: `git clone https://github.com/deltachat-bot/discourse-login-bot`

And finally I copied the config from the login-demo bot: `cp .login-dcrc discourse-login-bot/config/local.json`

Now I tried to start the bot:

```
cd discourse-login-bot
npm i
npm start
```

But it threw a Syntax Error. I restarted the login-demo bot for now and opened
an issue: https://github.com/deltachat-bot/discourse-login-bot/issues/2

@pabzm fixed it a few days later, so I could continue:

```
git pull origin master
npm i
npm start
```

Then I realized that the discourse-login-bot has a slightly different config
format; I changed it and ran npm start again.

This time, it started, and I tried it out. But when I clicked on "login with
Delta Chat", the web server returned "Cannot GET /oauth2/authorize".
Apparently some routes had changed.

To fix this, I went to the discourse config and changed the authorize URL from
`https://login.testrun.org/oauth2/authorize` to
`https://login.testrun.org/authorize`. I did the same with the token URL.

I tried to login again, and scanned the QR code, but this time, after I was
added to the login group, the web server returned "Bad Request". The
application log showed:

```
[3/17/2020, 11:04:28 AM] Request to /authorize
[3/17/2020, 11:04:28 AM] Request to /authorize
[3/17/2020, 11:04:28 AM] session contactId:  undefined
[3/17/2020, 11:04:28 AM] Unauthenticated request, sending login page
[3/17/2020, 11:04:28 AM] Request to /styles.css
[3/17/2020, 11:04:28 AM] Request to /requestQR
[3/17/2020, 11:04:28 AM] new group name: LoginBot group (f3e4)
[3/17/2020, 11:04:28 AM] new group_id: 10
[3/17/2020, 11:04:29 AM] Request to /favicon.ico
[3/17/2020, 11:04:33 AM] Request to /checkStatus
[3/17/2020, 11:04:33 AM] Looking for new contact in group 10
[3/17/2020, 11:04:33 AM] otherContacts in group: []
[3/17/2020, 11:04:38 AM] Request to /checkStatus
[3/17/2020, 11:04:38 AM] Looking for new contact in group 10
[3/17/2020, 11:04:38 AM] otherContacts in group: []
<- here I scanned the QR code ->
[3/17/2020, 11:04:44 AM] Request to /checkStatus
[3/17/2020, 11:04:44 AM] Looking for new contact in group 10
[3/17/2020, 11:04:44 AM] otherContacts in group: [ 10 ]
[3/17/2020, 11:04:44 AM] Storing contact ID in session
[3/17/2020, 11:04:44 AM] Request to /authorize
[3/17/2020, 11:04:44 AM] Request to /authorize
[3/17/2020, 11:04:44 AM] session contactId:  10
[3/17/2020, 11:04:44 AM] Authenticated request, calling next()
[3/17/2020, 11:04:44 AM] Request to /authorize
[3/17/2020, 11:04:44 AM] Unknown redirect_uri, denying access.
[3/17/2020, 11:04:45 AM] Group 1 was successfully created and joined by contact 10
[3/17/2020, 11:04:45 AM] Sending you-may-leave-message to chat 1
[3/17/2020, 11:04:45 AM] Leaving chat 1
[3/17/2020, 11:04:45 AM] Deleting chat 1
```

Then I realized that in the config directory there was still the test.json
config. It had a conflicting `redirect_uri` value. I removed the file with `rm
config/test.json` and restarted the application. Then I tried it again. This
didn't help, so I added a more verbose log message to the code, restarted the
application, and tried again.

I fixed a small bug in the code, then I encountered the next error; it
redirected me back to support.delta.chat, saying "Sorry, there was an error
authorizing your account. Please try again." The URL showed:
`https://support.delta.chat/auth/failure?message=invalid_credentials&origin=https%3A%2F%2Fsupport.delta.chat%2Flatest&strategy=oauth2_basic`

I opened https://github.com/deltachat-bot/discourse-login-bot/issues/5.

### Bot Deployment & Management

After @pabzm fixed that as well, we could deploy the bot with:

```
cd discourse-login-bot
forever start src/index.js
```

To stop it, you can execute `forever stopall`. To only restart it, 
`forever restartall`.

To find out where the log file is, or to get other info about the running
process, execute `forever list`.

### Fixing the Bot deployment

On 2020-04-02, we had to fix the bot deployment, because I had forgot to also
copy the database from the login-demo bot during migration to
discourse-login-bot.

The steps to fix this are described at
https://github.com/deltachat/sysadmin/tree/master/support.delta.chat#fixing-the-new-discourse-login-bot

### Configuring TMUX

After that, I did the effort to correctly configure tmux on login.testrun.org
on the missytake user.

I added the following lines to the .bashrc:

```
# autostart tmux
if [ -t 0 -a -z "$TMUX" ]
then
        test -z "$(tmux list-sessions)" && exec tmux new -s "$USER" || exec tmux new -A -s $(tty | tail -c +6) -t "$USER"
fi
```

And the following lines to ~/.tmux.conf:

```
set-option -g prefix C-a
set-option -g aggressive-resize on
set-option -g mouse on
set-option -g set-titles on
set-option -g set-titles-string '#I:#W - "#H"'
unbind-key C-b
bind-key ` send-prefix
bind-key a last-window
bind-key k kill-session
```

After that, I logged out and in again to apply the settings and check that they
work. It worked fine!

## Hardening NGINX

On 2020-04-23, pabz and I were notified that the TLS configuration of
login.testrun.org was not very optimal.  Both in /etc/nginx/nginx.conf and in
/etc/letsencrypt/options-ssl-nginx.conf was TLS 1.0 and TLS 1.1 allowed.

So we disallowed it in both config files, and removed the value in nginx.conf,
as it's overwritten by the let's encrypt config anyway.

pabz also added a "Secure"-flag to the session cookie, and I added an HSTS
header.

In the end, I committed the changes to etckeeper.

## Adding security backports

On 2020-01-27, a critical vulnerability in sudo was published, "Baron Samedit".
I patched all our servers - but on login.testrun.org I noticed that there was
no new version of sudo available from the repositories. So I added the
following line to /etc/apt/sources.list:

```
deb http://security.debian.org/debian-security buster/updates main contrib non-free
```

After that I ran `sudo apt update && sudo apt upgrade` to patch the
vulnerability.

## Secure SSH Access

Author: missytake@systemli.org

On 2021-04-23, we realized that SSH was not protected after the best practices.
So I forbade PasswordAuthentication in the `/etc/ssh/sshd_config` and installed
sshguard with `sudo apt install sshguard`. The default config seemed fine, so I
didn't touch anything.

