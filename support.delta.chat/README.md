# support.delta.chat Discourse Instance

This Discourse instance was set up by compl4xx@systemli.org. If something does
not work as expected, you can ask them what they did wrong.

## Login

Currently compl4xx, hpk, and pabz have access. If your SSH key is added, you
can login with this SSH config:

```
Host support.delta.chat
	User tech
	Port 42022
	IdentityFile /home/$USER/.ssh/$KEY
```

## Setup

I resized the disk image of this VM to 15 GB.

I then followed this setup guide for discourse, from this point on:
https://web.archive.org/web/20180420170222/https://github.com/discourse/discourse/blob/master/docs/INSTALL-cloud.md#install-discourse

The settings I chose during the setup script are in the secrets folder of the
private OTF repo, protected by git-crypt.

After the installation, I added the discourse-solved plugin:
https://meta.discourse.org/t/discourse-solved-accepted-answer-plugin/30155

## Update settings

On 2018-10-02, we had to update the e-mail settings because of a mail provider
change. The new settings are in the secrets folder as well.

I changed them in /var/discourse/containers/app.yml and updated them by
rebuilding the container with `./launcher rebuild app`.

## Backup

You can just backup and restore the whole docker container very easily:
https://meta.discourse.org/t/backup-discourse-from-the-command-line/64364

The backup server is defined in `/root/.ssh/config` as `backup`, so you can
refer to it like that in scripts which are executed by root. You can find this
file as well as the SSH private key in the secrets folder in the OTF repo.

I created a borg repository:

```
borg init backup:support.delta.chat --encryption=repokey
```

Backups are encrypted with a passphrase. You can find it in the secrets folder
in the OTF repo as well. To backup the whole container into the test repo:

```
export BORG_PASSPHRASE='password'
/var/discourse/launcher stop app
borg create --stats --progress --compression lzma backup:support.delta.chat::'backup{now:%Y%m%d}' /var/discourse/shared/standalone
/var/discourse/launcher start app
borg prune --keep-daily=7 --keep-weekly=4 backup:support.delta.chat
```

There are backups kept from the last 7 days, and 1 of every last 4 weeks.

## Restore

Backups are encrypted with a passphrase. Secrets folder, look above. To
restore the whole container from the test repo:

```
export BORG_PASSPHRASE='password'
/var/discourse/launcher stop app
rm -rf /var/discourse/shared/standalone
cd /
borg extract backup:support.delta.chat::thebackupyouwant
/var/discourse/launcher start app
```

## Maintenance: storage driver

In September 2019, suddenly the /var/discourse/launcher script complained about
the docker storage driver (overlay2), which apparently wasn't supported by
discourse anymore:

```
Your Docker installation is not using a supported storage driver. If we were to proceed you may have a broken install.
aufs is the recommended storage driver, although zfs/btrfs/overlay and overlay2 may work as well.
Other storage drivers are known to be problematic.
You can tell what filesystem you are using by running "docker info" and looking at the 'Storage Driver' line.

If you wish to continue anyway using your existing unsupported storage driver,
read the source code of launcher and figure out how to bypass this check.
```

According to [this forum
post](https://meta.discourse.org/t/cant-run-launcher-rebuild-app-docker-storage-driver-is-unsupported/56927/2)
a new storage driver was needed. First I shut down the container manually with
`sudo docker stop app` and executed `/var/discourse/backup.sh`, to make sure we
had a consistent, recent backup.

Then I added a custom dockerd config file in
`/lib/systemd/docker.service.d/docker.conf` with the following content:

```
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --storage-driver=aufs
```

Then I also created `/etc/docker/daemon.json`:

```
{
  "storage-driver": "aufs"
}
```

After which the docker daemon failed at restart. Finally, `journalctl -xe` told
me that the aufs storage driver isn't installed, and [the
Internet](https://stackoverflow.com/questions/37110291/how-to-enable-aufs-on-debian)
even said that it is not supported anymore by modern kernels.

As overlay2, the currently installed storage driver, was recommended everywhere
as the better solution (and is even the discourse people's second favorite), I
decided to just use overlay2. I removed my prior modifications again.

### Upgrading to get out of this mess

Discourse asked me to do this to upgrade the discourse instance to a new version:

```
cd /var/discourse
git pull
./launcher rebuild app
```

Afterwards, the launcher script didn't complain about the storage driver
anymore - apparently updating it with `git pull` sorted out the warning.

## Plugins

Over the years, I installed 2 plugins to this discourse instance:

- solved-checkbox: https://github.com/discourse/discourse-solved
- sitemap: https://github.com/discourse/discourse-sitemap

### Installing a Plugin

Source: https://meta.discourse.org/t/install-plugins-in-discourse/19157

I installed both plugins by adding a line to `/var/discourse/containers/app.yml` with the
command to clone the plugin into a certain directory, like this:

```
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/discourse/docker_manager.git
          - git clone https://github.com/discourse/discourse-solved.git
          - git clone https://github.com/discourse/discourse-sitemap.git
```

The docker_manager plugin came pre-installed.

Afterwards I rebuilt the container with `sudo /var/discourse/launcher rebuild
app` to actually install it in the container.

### Delta Chat Identity

Author: missytake@systemli.org

When we set up login.testrun.org, we installed the oauth2 plugin by adding the
following line to `/var/discourse/containers/app.yml` and rebuilding the container:

```
          - git clone https://github.com/discourse/discourse-oauth2-basic.git
```

#### OAuth2 Settings

Then new settings showed up in the admin settings. We filled out some of them
like this, others are saved in the secrets repo, protected by git-crypt:

```
oauth2 enabled: 			true
oauth2 client id: 			secret
oauth2 client secret: 			secret
oauth2 authorize url:			https://login.testrun.org/oauth2/authorize
oauth2 token url:			https://login.testrun.org/oauth2/token
oauth2 token url method:		POST
oauth2 callback user id path:		params.info.userid
oauth2 callback user info paths:	name:params.info.username
					email:params.info.email
oauth2 fetch user details:		false
oauth2 email verified:			true
oauth2 button title:			with Deltachat Identity
oauth2 allow association change:	true
```

#### custom css

Then we added some stuff to the custom css of the Footer theme:

```
button.btn-social.oauth2_basic {
    background: linear-gradient(120deg, #71828a, #4a6069) #159957;
}

.btn-social {
    line-height: 1.2; // fix login button text centering
}
```

Now it's possible to login with Delta Chat / login.testrun.org into
https://support.delta.chat :) 

#### Fixing the new discourse-login-bot

During March and April 2020, we replaced the login-demo bot with the
discourse-login-bot (see
https://github.com/deltachat/sysadmin/tree/master/login.testrun.org#installing-discourse-login-bot-instead-of-login-demo
for details). During the migration, I forgot to copy the database, which
resulted in data inconsistencies.

To complete the migration, I first disabled the OAuth2 plugin again.

Then I changed the `oauth2 callback user id path` from params.info.userid to
params.info.email, as the new bot doesn't transmit a user ID anymore, and uses
the email as unique identifier on the discourse side instead (see
https://github.com/deltachat-bot/discourse-login-bot/pull/9 for more
background).

Now I also had to delete the `user_associated_accounts` table from the
discourse database, to clean up the data we already had, and which was in parts
corrupted.

First I looked whether there were accounts in the `user_associated_accounts`
table which had no primary email set to their accounts, which would make them
unable to login. To do this, I logged in to support.delta.chat via SSH, and
opened the discourse database in the running docker container. After playing
around a bit with SQL, pabz came up with 
`select user_emails.user_id, user_emails.email, user_emails.primary, user_associated_accounts.info from user_associated_accounts left join user_emails on user_associated_accounts.user_id = user_emails.user_id;`
, which correctly showed that no user in the `user_associated_accounts` table
would lose the ability to login if we removed the entry.

Then I logged out of the discourse container and ran
`/var/discourse/backup.sh`, to backup discourse before we delete (maybe)
valuable data.

After that, I could open the database again and deleted all rows in the
`user_associated_accounts` table, with `delete from user_associated_accounts
returning *;`. That worked fine, after that, the table was empty.

Now I activated the OAuth2 app again in the discourse settings. I also switched
off the `oauth2 email verified` setting, because we wanted to see whether
https://github.com/deltachat-bot/discourse-login-bot/pull/10 works.

Then I updated the discourse-login-bot on login.testrun.org:

```
cd discourse-login-bot
git pull --autostash --rebase  # this command complained that there was a merge conflict when popping the stash and I needed to configure a git user to commit stuff
git config --global user.name "a"
git config --global user.email "a@a.a"
git pull --autostash --rebase
```

Then I resolved the merge conflict. pabz started the bot in his tmux session
with `forever start src/index.js`.

Now, as the bot was running again, I tried to login to the forum, but it only
offered me to create a new account with my email address - suspicious was, that
the form also said "we will email you to confirm" below my email address.

So I switched on the `oauth2 email verified` setting again, and suddenly
logging in worked, meaning that
https://github.com/deltachat-bot/discourse-login-bot/pull/10 didn't work as
expected.

So finally the discourse-login-bot worked!

## Migration to Hetzner

On 2020-04-17, I migrated the server to Hetzner. The steps are described in
https://github.com/deltachat/sysadmin/blob/master/backup/README.md#restore-migration-to-hetzner-cloud

## Footer Theme

Somewhat earlier, I don't remember when, we added a footer to the discourse
theme, with a privacy policy link.  This was done by creating a custom theme
called "Footer", adding some extra html + css, and making it the default theme.

Unfortunately, with javascript enabled, you rarely see the footer, only in
short categories, because scrolling down, just more and more posts are loaded.

On 2020-05-03 I added 3 more links to the footer, the Website, Mastodon, and
Twitter; mainly to have the forum show as verified on the Mastodon account.

## Upgrading docker setup manually

On 2021-02-05, I tried to upgrade the docker setup in the web interface.
Unfortunately, it didn't finish. So I just restarted the container and let it
be.

Every day since then, the forum crashed once a day, so 2 days later I decided
to upgrade it manually:

```
cd /var/discourse
sudo git pull
sudo ./launcher rebuild app
```

This prompted me with the possibility to free up space:

```
WARNING: We are about to start downloading the Discourse base image
This process may take anywhere between a few minutes to an hour, depending on your network speed

Please be patient

2.0.20201221-2020: Pulling from discourse/base
6ec7b7d162b2: Pull complete
488a5181297e: Pull complete
Digest: sha256:e181dd9046cc293b10c5b29bbc21c5aa8b939ba5f0c500da4a9e952ed0b5195d
Status: Downloaded newer image for discourse/base:2.0.20201221-2020
docker.io/discourse/base:2.0.20201221-2020
You have less than 5GB of free space on the disk where /var/lib/docker is located. You will need more space to continue
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        19G   15G  3,3G  82% /

Would you like to attempt to recover space by cleaning docker images and containers in the system? (y/N)y
If the cleanup was successful, you may try again now
```

After that, I ran `sudo ./launcher rebuild app` again. This time it downloaded the image and told me the following in the end:

```
Upgrade Complete
----------------
Optimizer statistics are not transferred by pg_upgrade so,
once you start the new server, consider running:
    ./analyze_new_cluster.sh

Running this script will delete the old cluster's data files:
    ./delete_old_cluster.sh
-------------------------------------------------------------------------------------
UPGRADE OF POSTGRES COMPLETE

Old 10 database is stored at /shared/postgres_data_old

To complete the upgrade, rebuild again using:

./launcher rebuild app
-------------------------------------------------------------------------------------

6aec0338889b9383494b00c8d01b64e4aac2eafc3ceaee03a0f238e0c3b7a7f6
```

So I ran `sudo ./launcher rebuild app` again. After this, the upgrade was
complete, and the container was running fine. I opened
https://support.delta.chat/admin/upgrade just to see that all upgrades had been
completed.

## Re-Setup the forum on a new machine

On 2021-02-09, Janek & missytake migrated the forum to a Hetzner VPS. This was
because the forum crashed basically once a day. As the last migration was quite
dirty anyway, we decided to do a proper re-setup.

### Basic steps

1. Rent a new hetzner cloud machine
2. setup: docker firewall etckeeper and update the machine
3. create new DNS entries
4. install discourse docker image
5. migrate the discourse volume
6. create backup job

### Renting a new VM

Janek clicked around on console.hetzner.cloud to create a new VM. It had the following specs:

- 1 vCPU
- 2 GB RAM
- 20 GB disk
- 2,96 €/month
- IP: 135.181.200.170

OLD IP:
95.217.213.142

#### Setup user + tmux

missytake created a user for our common tmux session:

```
adduser missytake
adduser missytake sudo
```

And with `sudoedit /etc/sudoers` missytake added `NOPASSWD: ` before `ALL` to
the %sudo line, to enable passwordless sudo.

missytake also configured tmux:

```
sudo apt install git tmux
curl -sfL https://git.io/chezmoi | sh  # Install chezmoi
git clone https://git.0x90.space/missytake/chezmoi-server ~/.local/share/chezmoi  # clone the repository
bin/chezmoi diff
bin/chezmoi apply
source ~/.bashrc
```

Now we had a tmux session to do this admin shit.

#### Installing Docker

Janek updated the server with `apt update` and `apt full-upgrade` and added the
docker repo to apt-sources and installed it with get.docker.com. Also missytake
was added to the docker group with `usermod -aG docker missytake`.

### Setup instructions:

Easy setup:
https://github.com/discourse/discourse/blob/master/docs/INSTALL-cloud.md

Docker install debian:
```
curl -sSL https://get.docker.com/ | CHANNEL=stable sh
systemctl enable docker.service
systemctl start docker.service
```

Docker compose:
```
curl -L https://github.com/docker/compose/releases/download/$(curl -Ls https://www.servercow.de/docker-compose/latest.php)/docker-compose-$(uname -s)-$(uname -m) > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

### Setup for discourse docker

Clone the repo:

```
sudo -s
git clone https://github.com/discourse/discourse_docker.git /var/discourse
cd /var/discourse
```

### Getting access to the backup

Author: missytake@systemli.org

First I installed borgbackup with `apt install borgbackup`.

Then I copy-pasted the support.delta.chat backup private SSH key from the old server to the new server and added the hetzner backup server to the SSH config:

```
vim /root/.ssh/backup
chmod 600 /root/.ssh/backup
vim /root/.ssh/config
```

To the SSH user config, I added:

```
Host hetzner-backup
    User u229552
    Hostname u229552.your-storagebox.de
    Port 23
    IdentityFile /root/.ssh/backup
```

Then I tried to connect to the borg server on the backup machine:

```
borg list hetzner-backup:backups/support.delta.chat
```

It asked me for the backup encryption password, which I found in the git crypt
secrets, and showed me the available backups.

We didn't restore the backup yet, as we wanted to do the setup properly first.

### Domains

Now we had to point the DNS entry to the new machine, so Let's Encrypt would
allow us to create a certificate. We changed the A entry of support.delta.chat
to the following:

```
A              support                    60      135.181.200.170
```

We also added an AAAA entry:

```
AAAA         support                  60     2a01:4f9:c011:10dc::1
```

### Setup Script

Launch the setup script
```
./discourse-setup
```

Enter the variables:

```
DISCOURSE_HOSTNAME: support.delta.chat
DISCOURSE_DEVELOPER_EMAILS: missytake@systemli.org'
DISCOURSE_SMTP_ADDRESS: v128803.kasserver.com
DISCOURSE_SMTP_PORT: 587
DISCOURSE_SMTP_USER_NAME: discourse@deltachat.net
DISCOURSE_SMTP_PASSWORD: s3cr3t
LETSENCRYPT_ACCOUNT_EMAIL: missytake@systemli.org
```

The script ran as expected.

### Restoring the backup

Now we could restore the backup with the following command:

```
borg list backup:support.delta.chat
cd /
borg extract -v --list backup:support.delta.chat::backup2021-02-09-22 --exclude var/discourse/shared/standalone/letsencrypt
```

To reinstall the plugins, we added the following 3 lines to containers/app.yml,
as described in
https://github.com/deltachat/sysadmin/tree/master/support.delta.chat#installing-a-plugin

```
          - git clone https://github.com/discourse/discourse-solved.git
          - git clone https://github.com/discourse/discourse-sitemap.git
          - git clone https://github.com/discourse/discourse-oauth2-basic.git
```

Then we executed `sudo /var/discourse/launcher rebuild app` to install them.

But it didn't work. When the container was restarted, it went into a loop, but
didn't boot properly.

## Second try.

So we tried again:

```
rm -rf /var/discourse
git clone https://github.com/discourse/discourse_docker.git /var/discourse
cd /var/discourse
docker kill app
docker rm app
./discourse-setup
```

We entered the variables:

```
DISCOURSE_HOSTNAME: support.delta.chat
DISCOURSE_DEVELOPER_EMAILS: missytake@systemli.org'
DISCOURSE_SMTP_ADDRESS: lists.codespeak.net
DISCOURSE_SMTP_PORT: 25
DISCOURSE_SMTP_USER_NAME: delta-noreply
DISCOURSE_SMTP_PASSWORD: s3cr3t
LETSENCRYPT_ACCOUNT_EMAIL: missytake@systemli.org
```

When it was at the rebuilding step, we canceled the process with ctrl+c and
added the plugins as described above. Then we ran `./launcher rebuild app`
again. Afterwards the container was running.

### Restore Backup

First missytake logged back into the old forum and created and downloaded a
backup, like described in
https://meta.discourse.org/t/create-download-and-restore-a-backup-of-your-discourse-database/122710.
Then they uploaded that backup to the new server, and restored it via command
line, like described in
https://meta.discourse.org/t/restore-a-backup-from-command-line/108034.

Then it was running fine again :) Only emails were somehow disabled for
non-staff users - we reverted that change.

## etckeeper

On 2021-02-24 I, missytake, realized that etckeeper wasn't installed. I installed it.

## Backup solution

When I saw which restore way had worked in the end, I planned to create yet another
backup solution. I enabled automated database backups in the web interface, after
this guide: https://meta.discourse.org/t/configure-automatic-backups-for-discourse/14855

So I changed `backup frequency` to 1 and `maximum backups` to 7. I chose local storage as
storage provider, which was the default. This means the backups are saved at
`/var/discourse/shared/standalone/backups/default`. From there, a borgbackup cron job can
copy them to our backup server, together with the rest of the container.

I copied the backup.sh script from this repository to
`/var/discourse/backup.sh`, and added the backup password from the git secrets.

Then I ran a test run - it completed fine.

Finally I added the following line to `/etc/cron.d/borgbackup`: 

```
35 2 * * * root /var/discourse/backup.sh
```

Now the backup should run nightly.

## Secure SSH Access

Author: missytake@systemli.org

On 2021-04-23, we realized that SSH was not protected after the best practices.
So I forbade PasswordAuthentication in the `/etc/ssh/sshd_config` and installed
sshguard with `sudo apt install sshguard`. The default config seemed fine, so I
didn't touch anything.

## Fixing blank page issue

2021-07-04
After realizing [that emails sent by the supportforum are being rejected](https://github.com/deltachat/sysadmin-issues/issues/27), we updated the forum to the newest version. It started to return a blank page. We tried restarting and rebuilding the container, but it didn't help. After some research we tried this [fix](https://meta.discourse.org/t/blank-white-page-after-update/44678/13), setting the branch variable in app.yml to stable and then rebuilding again. Afterwards it seemed to work again. But shortly after we got reports, that the preferences and user profile did result in a 404.

We reverted these changes again, rebuilt and the settings were back and the page wasn't blank anymore. Seemingly changing the branch to be checked out, as suggested in the above mentioned fix only forced a full rebuild, which was not achived with `/var/discourse/launcher rebuild app`.

docker-compose has an option like 'docker-compose rebuild --no-cache'. Discourse has an wrapper script for docker called /var/discourse/launcher. Apperently it is possible to pass docker args to this script with `/var/discourse/launcher --docker-args --no-cache rebuild app`
