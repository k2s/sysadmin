# The Ultimate Universal Backup Solution

Author: missytake@systemli.org

On 2020-04-13 I started to create one backup solution to rule them all. The
idea was to have full backups of each server one day, which can be restored
quickly. We decided to go with borgbackup and Hetzner backup space.

The machines which are backed up there are:

* [x] page
* [ ] login.testrun.org
* [x] b1.delta.chat
* [ ] hq4
* [x] hq5
* [x] support.delta.chat
* [ ] devpi.net
* [ ] lists.codespeak.net

At this point, it wasn't yet clear which backup method to use. There were 4
options in discussion:

1. borgbackup + whole disk image. problem: how do we get a disk image without inconsistencies? is stopping services beforehand enough? is it practicable to turn the disk image read-only for the duration of the backup?
2. borgbackup + root directory, except /dev, /sys, and /proc. I hope shutting down services in the beginning is enough to avoid inconsistencies.
3. borgbackup + snapshots. problem: most servers have an ext4 file system without a logical volume.
4. borgbackup + this tool to create disk dumps, which is unmaintained for ext4, but widely used on BSD afaik: https://dump.sourceforge.io/ - sounds not like a very good idea.

## Renting Backup Space

After I gathered the needed info about the backup space, I rented some backup
space at Hetzner. Under https://robot.your-server.de/server, I clicked on
b1.delta.chat, then on Backup, and then booked a BX20 box for 5,83€/month.

I activated SSH support.

Then I switched to "Snapshots" and created an initial snapshot, to be able to
restore that point in time later.

Then I created a new password and saved it in my password manager for now.

I also switched on "Reachable from the outside", so we could backup page &
login.testrun.org.

Then I created the .ssh folder with Filezilla and added my public key to
`/.ssh/authorized_keys`.

## support.delta.chat

I started with support.delta.chat. First I added the existing
support.delta.chat backup SSH public key to `authorized_keys` on the backup
server:

```
scp -P 23 u229552@u229552.your-storagebox.de:.ssh/authorized_keys authkeys
echo -n 'command="borg serve --restrict-to-path /backups/support.delta.chat/",restrict ' >> authkeys
cat .ssh/id_rsa.pub >> authkeys
scp -P 23 authkeys u229552@u229552.your-storagebox.de:.ssh/authorized_keys
```

There was no obvious way to reload the SSH config on the storage box.

Then I created a borg repository for trying a file system backup according to
option 2. I generated a new password for the backup and stored it in my
personal pass repository, as well as the git secrets in the otf-repo:

```
export BORG_PASSPHRASE='secret'
borg init --encryption=repokey hetzner-backup:backups/support.delta.chat/
```

Then I created a new backup script for the hetzner-backup - you can find it at
/root/hetzner-backup.sh. For reference, I copied it to this repository.

A first backup run was successful, took about an hour, and the compression
reduced the backup size to only a third.

### Restore: Migration to Hetzner Cloud

To test the restore mechanism, I migrated support.delta.chat to a fresh VPS in
the Hetzner Cloud.

#### Step 1: Create VPS

I created the VPS with the following specs:

- Location: Finland
- CX 11 (the specific Hetzner VPS product)
- 20 GB SSD disk space
- Debian 9(.12, while the original machine is running Debian 9.11)
- 2 GB RAM
- 1 VCPU
- I added my SSH public key to the server through the web interface.

Hetzner gave me an IP, so I could login with `ssh root@95.217.213.142`.

#### Step 2: Install Borgbackup

I installed borgbackup 1.0.9, because that's the version in the debian 9
sources, and also installed on the old VM:

```
apt update
apt install borgbackup vim
```

#### Step 3: Restore Backup

First I copy-pasted the support.delta.chat backup private SSH key to the new
server and added the hetzner backup server to the SSH config:

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

It asked me for the backup encryption password, which I had stored in my
personal pass repository, and showed me the one available backup.

So I restored the backup, first with a dry run (-n), then for real:

```
cd /
borg extract -n -v --list hetzner-backup:backups/support.delta.chat::backup2020-04-14-02 --exclude boot --exclude vmlinuz
borg extract -v --list hetzner-backup:backups/support.delta.chat::backup2020-04-14-02 --exclude boot --exclude vmlinuz
```

I noticed that existing files were not deleted - only overwritten, if there was
a file in the backup which replaced them.  But for the most part that is quite
good, e.g. for some systemd files which are present on each Hetzner VPS
(`/etc/init/cloud*` and `/etc/init.d/cloud*`, for example). Probably not a good
thing if they were overwritten during restore.

Then I tried to reboot - after which I could not login per SSH anymore.
Probably because the restored SSH config didn't allow login as root... I had to
destroy the VPS and try it again. Only this time, I also excluded initrd.img:

```
cd / && borg extract -v --list hetzner-backup:backups/support.delta.chat::backup2020-04-14-02 -e boot -e vmlinuz -e initrd.img
```

The restore went well. And this time, before I did anything, I allowed root
login before I reloaded the SSH service ;)

Now I tried rebooting again, but after that the SSH port was closed (as well as
all other ports).

So I deleted the server again and created it a third time, only this time, with
the restore, I also left out the whole /etc directory:

```
cd / && borg extract -v --list hetzner-backup:backups/support.delta.chat::backup2020-04-14-02 -e boot -e vmlinuz -e initrd.img -e etc
```

problems: 
- services are in /etc
- network settings are in /etc
- user stuff is in /etc

So I realized I needed some files from /etc as well, to run the services and
restore the users/groups, and I ran a second restore command:

```
cd / && borg extract -v --list hetzner-backup:backups/support.delta.chat::backup2020-04-14-02 etc/passwd etc/shadow etc/group etc/gshadow 're:^etc/rc[0-9A-Z].d' etc/init.d etc/init etc/systemd lib/systemd run/systemd etc/docker etc/exim4
```

After that, I dared to reboot again. It worked suprisingly well, I could even
login as tech, and the docker service was there! I added the following line to
the `/etc/hosts` file on my local machine to check whether the web interface
was responding:

```
95.217.213.142  support.delta.chat
```

Unfortunately, opening the website in firefox threw a 502 error. Maybe because
the DNS entry still didn't point to the new server?

So I reinstalled the whole server, pointed the DNS entry to the new IP, and
confirmed that it worked with `dig support.delta.chat` - it seemed that the
website worked for half a minute in an anonymous tab, but soon afterwards
showed the 502 error again.

After a bit of investigating I found the error - inside the discourse docker
container, the file permissions for `/shared/postgres_data` were 105:109
instead of 106:109, Debian-exim4:postgres instead of postgres:postgres. On the
old server, the file permissions were indeed 106:109, so somehow the extract
process must have changed it. 

I decided to do the whole process again, and this time use the numeric user &
group IDs for the borg extract command, as the /etc/passwd file was also
restored as well.

```
cd / && borg extract -v --list hetzner-backup:backups/support.delta.chat::backup2020-04-14-02 etc/passwd etc/shadow etc/group etc/gshadow 're:^etc/rc[0-9A-Z].d' etc/init.d etc/init etc/systemd lib/systemd run/systemd etc/docker etc/exim4
cd / && borg extract -v --numeric-owner --list hetzner-backup:backups/support.delta.chat::backup2020-04-14-02 -e boot -e vmlinuz -e initrd.img -e etc
reboot
```

That worked! It looked good in the browser, although the restored backup was
visibly 2 days old of course ;) 

##### Trying out other restore commands

```
cd / && borg extract -v --numeric-owner --list hetzner-backup:backups/support.delta.chat::backup2020-04-14-02 etc -e boot -e vmlinuz -e initrd.img -e etc/network
```

This command unfortunately didn't work. After the reboot, the VPS wasn't
reachable under that IP anymore (but turned on, according to the Hetzner web
interface).

So I went through the other working migration steps again.

Then I created a second backup cronjob on the old support.delta.chat, to bring
the backup up to date again, by running `crontab -e` as root, and adding this
line:

```
35 2 * * * /root/hetzner-backup.sh
```

This night, after the backup completed, I ran the following restore commands on
the new machine again:

```
cd /
sudo borg extract -v --list hetzner-backup:backups/support.delta.chat::backup2020-04-17-02 etc/passwd etc/shadow etc/group etc/gshadow 're:^etc/rc[0-9A-Z].d' etc/init.d etc/init etc/systemd lib/systemd run/systemd etc/docker etc/exim4
sudo borg extract -v --numeric-owner --list hetzner-backup:backups/support.delta.chat::backup2020-04-17-02 -e boot -e vmlinuz -e initrd.img -e etc
sudo reboot
```

After that, I looked at the website, but there were some inconsistencies in the
database, so I tried another restore command:

```
cd /
sudo rm -rf var/discourse/shared/standalone/*
sudo borg extract -v --list hetzner-backup:backups/support.delta.chat::backup2020-04-17-02 var/discourse/shared/standalone
sudo reboot
```

#### Step 4: Point DNS to VPS 

After I confirmed that the website worked as expected, I pointed the DNS A
entry for support.delta.chat to the new IP:

```
Type    Name            Value                   TTL
A       support         95.217.213.142          60
```

Now I could also test login with Delta Chat (via login.testrun.org) - that
worked as expected, I could login to my account. 

One final step: because the SSH config hadn't been copied, I disabled root SSH
access afterwards and reloaded the SSH server, so the changes could take
effect.

Migration complete!

## page

what's supposed to work after restore?
- nginx is running
- websites are displayed:
    - delta.chat
    - bots.delta.chat
    - get.delta.chat, download.delta.chat
- files linked on get.delta.chat are all downloadable
- deltachat-pages & bot-pages GitHub actions work

First, I generated an SSH keypair (without a passphrase) on page:

```
sudo su
cd ~
ssh-keygen -t ed25519 -f .ssh/backup
```

Then I added the following line to the `.ssh/authorized_keys` file on the
backup server:

```
command="borg serve --restrict-to-path /backups/page/",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJAFkwf9W9BAdX16aFDzlkMTkURzxEJPPKkIsq4z9QX8 root@page
```

Now I also created the /root/.ssh/config file on page, and added the backup
server:

```
Host hetzner-backup
        Hostname u229552.your-storagebox.de
        User u229552
        IdentityFile /root/.ssh/backup
        Port 23
```

Now I installed borgbackup on page:

```
apt update
apt install -y borgbackup
```

Then I created a borg repository for trying a file system backup according to
option 2. I generated a new password for the backup and stored it in my
personal pass repository, as well as the git secrets in the otf-repo:

```
export BORG_PASSPHRASE='secret'
borg init --encryption=repokey hetzner-backup:backups/page
```

Then I created a new backup script for the hetzner-backup - you can find it at
/root/backup.sh. For reference, I copied it to this repository.

Now I also configured a cronjob on page to backup each night:

```
chmod 700 /root/backup.sh
echo "0 4 * * * root /root/backup.sh" > /etc/cron.d/backup
service cron reload
etckeeper commit "cronjob for backup"
```

## b1.delta.chat

what's supposed to work after restore?
* The android nightlys should still be built each night
* CI jobs should run?

First, I generated an SSH keypair (without a passphrase) on the server:

```
sudo su
cd ~
ssh-keygen -t ed25519 -f .ssh/backup
```

Then I added the following line to the `.ssh/authorized_keys` file on the
backup server:

```
command="borg serve --restrict-to-path /backups/b1/",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO70pJcJoRtJlBZn3tBWkohoItzioTJB0UJsoOrz0FYf root@b1
```

Now I also created the /root/.ssh/config file on the server, and added the backup
server:

```
Host hetzner-backup
    Hostname u229552.your-storagebox.de
    User u229552
    IdentityFile /root/.ssh/backup
    Port 23
```

Now I installed borgbackup on the server:

```
apt update
apt install -y borgbackup
```

Then I created a borg repository for trying a file system backup according to
option 2. I generated a new password for the backup and stored it in my
personal pass repository, as well as the git secrets in the otf-repo:

```
 export BORG_PASSPHRASE='secret'
borg init --encryption=repokey hetzner-backup:backups/b1 --remote-path=borg-1.0
```

Then I created a new backup script for the hetzner-backup - you can find it at
/root/backup.sh. For reference, I copied it to this repository.

Now I also configured a cronjob on the server to backup each night:

```
chmod 700 /root/backup.sh
echo "0 4 * * * root /root/backup.sh" > /etc/cron.d/backup
service cron reload
etckeeper commit "cronjob for backup"
```

## hq4

what's supposed to work after restore?
- apache2
- mysql ?
- mail.codespeak.net dovecot postfix

First, I generated an SSH keypair (without a passphrase) on the server:

```
ssh-keygen -t ed25519 -f .ssh/backup
```

Then I added the following line to the `.ssh/authorized_keys` file on the
backup server:

```
command="borg serve --restrict-to-path /backups/hq4/",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC11oY42xC7wJ2uWdsT6rNk+ENsQDEp4uTMpKNeKrZL9 root@hq4
```

Now I also created the /root/.ssh/config file on the server, and added the backup
server:

```
Host hetzner-backup
    Hostname u229552.your-storagebox.de
    User u229552
    IdentityFile /root/.ssh/backup
    Port 23
```

Now I installed borgbackup on the server:

```
apt update
apt install -y borgbackup
```

That failed, because borgbackup wasn't available in the repos. So I just used
the pre-compiled binaries from GitHub:

```
wget https://github.com/borgbackup/borg/releases/download/1.1.11/borg-linux64 -O /usr/local/bin/borg
#chmod +x /usr/local/bin/borg  # tbd
```

Then I created a borg repository for trying a file system backup according to
option 2. I generated a new password for the backup and stored it in my
personal pass repository, as well as the git secrets in the otf-repo:

```
 export BORG_PASSPHRASE='secret'
borg init --encryption=repokey hetzner-backup:backups/hq4
```

Then I created a new backup script for the hetzner-backup - you can find it at
/root/backup.sh. For reference, I copied it to this repository.

Now I also configured a cronjob on page to backup each night:

```
chmod 700 /root/backup.sh
echo "5 4 * * * root /root/backup.sh" > /etc/cron.d/backup
service cron reload
etckeeper commit "cronjob for backup"
```

## testrun.org

what's supposed to work after restore?
- dovecot
- postfix
- nginx
- docker?
- ssh
- unattended-upgrades
- zerotier-one

First, I generated an SSH keypair (without a passphrase) on the server:

```
ssh-keygen -t ed25519 -f .ssh/backup
```

Then I added the following line to the `.ssh/authorized_keys` file on the
backup server:

```
command="borg serve --restrict-to-path /backups/testrun.org/",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKpGDAov49uTssB+67CfL29wUF+w+//N5NrZbAs4H4lJ root@hq5
```

Now I also created the /root/.ssh/config file on the server, and added the backup
server:

```
Host hetzner-backup
    Hostname u229552.your-storagebox.de
    User u229552
    IdentityFile /root/.ssh/backup
    Port 23
```

Now I installed borgbackup on the server:

```
apt update
apt install -y borgbackup
```

Then I created a borg repository for trying a file system backup according to
option 2. I generated a new password for the backup and stored it in my
personal pass repository, as well as the git secrets in the otf-repo:

```
 export BORG_PASSPHRASE='secret'
borg init --encryption=repokey hetzner-backup:backups/testrun.org
```
Then I created a new backup script for the hetzner-backup - you can find it at
/root/backup.sh. For reference, I copied it to this repository.

Now I also configured a cronjob on the server to backup each night:

```
chmod 700 /root/backup.sh
echo "10 4 * * * root /root/backup.sh" > /etc/cron.d/backup
service cron reload
etckeeper commit "cronjob for backup"
```

## login.testrun.org

what's supposed to work after restore?
- nginx
- forever discourse-login-bot
- ssh
- unattended-upgrades

First, I generated an SSH keypair (without a passphrase) on the server:

```
sudo su
cd ~
ssh-keygen -t ed25519 -f .ssh/backup
```

Then I added the following line to the `.ssh/authorized_keys` file on the
backup server:

```
command="borg serve --restrict-to-path /backups/login.testrun.org/",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPyecQH35BnS2Mj3R2dHM4Hw8uIY7/aM5M6U+6Uok8YJ root@login.testrun.org
```

Now I also created the /root/.ssh/config file on the server, and added the backup
server:

```
Host hetzner-backup
    Hostname u229552.your-storagebox.de
    User u229552
    IdentityFile /root/.ssh/backup
    Port 23
```

Now I installed borgbackup on the server:

```
apt update
apt install -y borgbackup
```

Then I created a borg repository for trying a file system backup according to
option 2. I generated a new password for the backup and stored it in my
personal pass repository, as well as the git secrets in the otf-repo:

```
 export BORG_PASSPHRASE='secret'
borg init --encryption=repokey hetzner-backup:backups/login.testrun.org
```

Then I created a new backup script for the hetzner-backup - you can find it at
/home/missytake/backup.sh. For reference, I copied it to this repository.

During writing the script, I realized I had to run forever commands as the
missytake user. So I rewrote the whole script for being run by the missytake
user, and changed my above steps with the following commands:

```
mv /root/.ssh/backup* /home/missytake/.ssh/
mv /root/.ssh/config /home/missytake/.ssh/
chown missytake:missytake /home/missytake/.ssh/*
exit
sed -ie 's/root/home\/missytake/' .ssh/config
```

Now I also configured a cronjob on the server to backup each night:

```
chmod 700 /home/missytake/backup.sh
sudo sh -c 'echo "10 4 * * * missytake /home/missytake/backup.sh" > /etc/cron.d/backup'
sudo service cron reload
sudo etckeeper commit "cronjob for backup"
```

## devpi.net

what's supposed to work after restore?
generate backup SSH key
copy public key to backup server
create SSH config
install borgbackup
initialize repository
create backup script
create cronjob

## lists.codespeak.net

what's supposed to work after restore?
generate backup SSH key
copy public key to backup server
create SSH config
install borgbackup
initialize repository
create backup script
create cronjob

