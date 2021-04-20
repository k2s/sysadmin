# testrun.org

Author: missytake@systemli.org

testrun.org is a playground; many people do different things here. Not
everything is documented, but there is etckeeper to keep track of changes.

It runs on a VPS in the Hetzner Cloud; the DNS settings are at Hetzner as well.

Many users have sudo; passwords are not required.

Mostly postfix, dovecot, and a static nginx site are running here.

testrun.org offers an API for burner accounts, the code is here:
https://github.com/deltachat/tadm

Docker is installed, but only used if someone needs it.

## Mail Server Administration

### SPF

End of December 2019 we noticed that some mails to mailbox.org don't arrive, if
the recipient's Spam filter is set to `strict`.

I added an SPF record to the Hetzner DNS:

```
@      IN TXT     "v=spf1 a:testrun.org -all"
```

I also added a Reverse DNS entry for testrun.org in the Hetzner Cloud Network
settings. You can find them here:
https://console.hetzner.cloud/projects/311332/servers/83974/network

Finally, I changed the hostname in the `smtpd_banner` to testrun.org, because
mailbox.org complained about the HELO name.

After this, the spam issue was fixed.

## Migration to Bare Metal Machine

In 2020-06-07, I migrated testrun.org to a bare metal machine from the Hetzner
Serverbörse. It has the following specs:

* 2x 1TB HDD
* 16GB RAM

After I saw that the server was ready, I could connect via SSH to the rescue
system (a Debian 10 buster system): `ssh root@176.9.92.144`

First I created partition tables on both sda & sdb:

```
parted /dev/sda mklabel gpt
parted /dev/sdb mklabel gpt
```

### Basic System

Now I continued to install Debian 9 in the rescue system. I started
the `installimage` command (documentation:
https://wiki.hetzner.de/index.php/Installimage/en):

```
installimage
```

I wanted to install a Debian 9; unfortunately the disk encryption didn't
work with Debian 9:

```
Debian
Debian-912-stretch-64-minimal
```

And the options I chose in the choosing screen:

```
DRIVE1 /dev/sda
DRIVE2 /dev/sdb
SWRAID 1
SWRAIDLEVEL 1
HOSTNAME hq5
PART swap swap 8G
PART /boot ext3 512M
PART / ext4 all
IMAGE /root/.oldroot/nfs/images/Debian-912-stretch-64-minimal.tar.gz
```

I saved & exitted with F10, confirmed to write the system to /dev/sda and
/dev/sdb, and waited for the installation to complete. After that, I rebooted:

### Restore backup

First I copy-pasted the testrun.org backup private SSH key to the new
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

Now I had to install borgbackup on the new server: `apt update && apt install -y borgbackup`

Then I tried to connect to the borg server on the backup machine:

```
borg list hetzner-backup:backups/testrun.org
```

So I ran a restore command to migrate testrun.org to the new server:

```
cd / && borg extract -v --list hetzner-backup:backups/testrun.org::backup2020-06-07-04 -e boot -e vmlinuz -e initrd.img -e etc/network -e etc/initramfs-tools -e etc/kernel -e etc/grub.d -e etc/modprobe.d -e etc/resolvconf -e etc/sysctl.d -e etc/debian_version -e etc/fstab -e etc/resolv.conf
```

After that, I rebooted and logged in with the user I had on testrun.org: it
worked. I took a look at `sudo service --status-all` on both machines, and
noticed a few differences. Some new services showed up by default:

```
 [ - ]  cryptdisks
 [ - ]  cryptdisks-early
```

I ran `sudo etckeeper vcs diff` to see which files were added from before the
restore; then I committed the changes to etckeeper with `sudo etckeeper commit
"restored from backup"`, to be able to reverse them if things didn't work.

### Testing whether the migration worked

#### Services which need to work after restore

Now I wanted to test the functionality of testrun.org:

- dovecot (and postfix): receiving email
- postfix: sending email
- zerotier-one
- nginx: testrun.org reachable, apk-1.9.4-debug downloadable
- etckeeper: keep history?

### Initial tests with /etc/hosts

So I first added the IP of the new server as adress for testrun.org to my local
/etc/hosts file, and wrote a mail from one testrun.org account to another, with
the desktop client on my laptop; the mail appeared in /var/log/mail/mail.log,
and was properly received in my desktop client with the second account, a
temporary account.

When I replied with the temporary account, the email was sent immediately as
well, but my non-temp account didn't receive it.  In thunderbird it was shown
in the inbox folder, but "Loading Message..." never really completed.

The zerotier-one service was running, so I assumed it worked correctly. I don't
know the service well enough to conduct further tests; it doesn't seem very
important to me either.

Regarding nginx, https://testrun.org was available, and also custom links like
https://testrun.org/deltachat-fat-debug-1.9.4.apk were working.

The etckeeper history was visible with `etckeeper vcs log`, so everything
seemed to work fine :)

### Testing with x.testrun.org

#### Configuring Server as x.testrun.org

Now I wanted to test whether the restored server could interact with others as
a mailserver. So I registered the following 2 DNS entries:

```
A       x       900     176.9.92.144
MX      x       900     x.testrun.org
```

And added ` x.testrun.org` to the `virtual_mailbox_domains` config key in
`/etc/postfix/main.cf`.

I also wanted to create two test accounts to try it out, so I logged into the
mailadm user, changed the `/home/mailadm/mailadm.config` so x.testrun.org
addresses were possible, and created two addresses:

```
sudo su -l mailadm
vim mailadm.config  # changed line 4 & 5 "s/testrun.org/x.testrun.org"
mailadm add-user tmp.aiaud@x.testrun.org
mailadm add-user tmp.uhuhu@x.testrun.org
```

Then I tried to login to the two accounts with my Delta Chat clients; I had to
specify `x.testrun.org` as IMAP & SMTP server manually, and had to specify the
whole email address as IMAP login name and as SMTP login name to make it work.

#### Test Cases: Which Mails Worked

I exchanged two mails between the two mail accounts; everything worked as
expected.

Then I wrote a mail to asdf@testrun.org, an existing account on the old server;
it arrived in thunderbird, but not in Delta Chat.

Then I wrote two messages to missytake@systemli.org; the first didn't arrive
(probably due to greylisting), the second arrived both in thunderbird, and in
Delta Chat. When I tried to answer, I received a mailer daemon message, that
systemli.org failed to look up "x.testrun.org.testrun.org". Apparently I had
set the MX entry wrong; I changed it to:

```
MX      x       900     x
```

Then I tried the same with a different mail server, because I couldn't rely on
systemli.org flushing their DNS cache; so I wrote a message to
deltaprovider@aol.com. It arrived quickly; the response from aol.com took a bit
longer, but arrived as well.

#### Creating TMP accounts per web API

Then I tried creating a QR code via web API; I copied
/etc/nginx/sites-available/testrun.org to
/etc/nginx/sites-available/x.testrun.org, changed the server name to
x.testrun.org, removed the lines to the certificate paths, enabled the config
with `sudo ln -s /etc/nginx/sites-available/x.testrun.org
/etc/nginx/sites-enabled/`, and reloaded the nginx service.

Then I appended `x.testrun.org` to `/etc/dehydrated/domains.txt`, and ran
`dehydrated -c` to generate an extra TLS certificate for x.testrun.org.  I
readded the lines for the certificate paths, reloaded nginx, and visited
x.testrun.org, to be greated by a giant dinosaur!  Which was expected, and
good.

I also restarted the mailadm service with `sudo systemctl restart mailadm`, to
apply my changes to the config.

#### Testing Burner Account Creation with x.testrun.org

Now that HTTPS was working for x.testrun.org, I could try to generate an
account via curl. I did so with:

```
curl -X POST "https://x.testrun.org/new_email?t=1w_96myYfKq1BGjb2Yc&maxdays=7.0"
```

This worked, and I could login.

### Final Migration

Finally, some night on the old machine, I did one last backup, and after that
stopped the nginx, dovecot, and postfix service.

Then I extracted that last backup on the new machine:

```
borg extract -v --list hetzner-backup:backups/testrun.org::backup2020-06-10-02 -e boot -e vmlinuz -e initrd.img -e etc/network -e etc/initramfs-tools -e etc/kernel -e etc/grub.d -e etc/modprobe.d -e etc/resolvconf -e etc/sysctl.d -e etc/debian_version -e etc/fstab -e etc/resolv.conf
```

Finally I ran a quick rsync to copy the mails to the new server:

```
cd /home/vmail
rsync -r -p -P testrun.org:/home/vmail/testrun.org .
chown vmail:vmail testrun.org -R
```

#### Changing DNS

While the restore job was running, I switched the testrun.org DNS records so
they pointed to the new server:

```
A       @       900     176.9.92.144
A       tox     900     176.9.92.144
AAAA    @       900     2a01:4f8:151:338c::2
```

A codespeak.net record also pointed to the old machine, so I changed it:

```
A       @       1800    176.9.92.144
```

As with merlinux.de:

```
A       @       1800    176.9.92.144
```

#### Final tests

After that I restarted nginx, postfix, and dovecot, and repeated the tests I
previously did with x.testrun.org. Everything went fine:

- creating a temporary account via the mailadm CLI tool
- writing mails from compl4xx@testrun.org to that new temp account
- receiving mails with a testrun.org account
- writing to and receiving mails from a systemli.org account (though the first
  message often got lost or delayed, probably due to greylisting or so)
- creating a burner account by scanning a QR code
- creating a burner account with a curl request

#### Different rsync command

As there were complaints about old mails which arrived a second time, I tried
again with a different rsync command:

```
rsync -aPv testrun.org:/home/vmail/testrun.org .
```

## Migrating User Authentication to a Database

First I copied the userdb away as a backup:

```
cp /home/vmail/userdb /root/migration_backup/
cp /etc/postfix/virtual_mailboxes /root/migration_backup/
sudo -iu mailadm
mailadm prune
```

We also cleaned up some users in `/etc/postfix/virtual_mailboxes` and
`/etc/dovecot/?`.

### Installing mailadm tool for mailadm2

We decided to use a new user for the new mailadm setup. So we followed the
steps in https://mailadm.readthedocs.io/en/latest/#quickstart by first cloning
the https://github.com/deltachat/mailadm repository, and then changing some
config values in `install_mailadm.sh`.

We had to install dovecot-sqlite and had to upgrade all dovecot packages to the
state of stretch-backports (1:2.3.4.1-5+deb10u1~bpo9+1).

hpk then fixed some issues we stumbled upon, for details see
https://github.com/deltachat/mailadm/pull/16.

### Migrating old authentication files to mailadm2 database

The old mailadm bot saved the authentication in 3 files:
`/home/mailadm/userdb`, `/home/mailadm/postfix-users`,
`/home/mailadm/dovecot-users`.

I wrote a quick python script to migrate the entries from these files to the
`/var/lib/mailadm2/mailadm.db` database (you can find it in this repository.

Then I ran it:

```
cd /var/lib/mailadm2
sudo cp mailadm.db mailadm.db.backup
cd ~
sudo ./migrate-to-db.py
```

After running the script, the db had 779 users entries.

### Switching off the old mailadm in NGINX

Now I switched off the old route to `localhost:3961/new_email`, and added a new
one to localhost:3691, where mailadm2 listens.

### Switching off the old mailadm completely

I checked that no cronjobs were running for the old mailadm, e.g. no mailadm
prune job.

Finally I ran `sudo systemctl disable mailadm` to disable it completely.

### Added .bashrc

After that I noticed that when I logged into mailadm2 with `sudo -u mailadm2
bash` and ran `mailadm config`, it reported that the database was not
initialized. Apparently it tried to use the DB at /home/mailadm/mailadm.db
instead of the new one.

So I added the following two lines to /var/lib/mailadm2/.bashrc:

```
source ~/venv/bin/activate
export MAILADM_DB=$HOME/mailadm.db
```

I also ran `sudo usermod --shell /bin/bash mailadm2` to set bash as default
shell for mailadm2.

I logged out and in again, and now it worked.

## Upgrade to Debian 10

Authors: missytake@systemli.org & janek@merlinux.eu

On 2020-01-18, we upgraded testrun.org from debian stretch to buster (debian 10
current stable release) and deployed TLSv1.3.

We will use this guide:
https://linuxconfig.org/how-to-upgrade-debian-9-stretch-to-debian-10-buster

We searched for third-party sources with `aptitude search '~i(!~ODebian)'`
There's zerotier-one installed which should also be upgraded to debian buster,
but isn't a priority for us, because it came from an earlier installation.

Before the upgrade, we checked whether the last backup job was successful. To
check this, we ran `borg list hetzner-backup:backups/testrun.org` as root to
see the name of the last backup, and then `borg list
hetzner-backup:backups/testrun.org::backup2021-01-18-04`. This printed the list
of files which were backed up successfully last night - it looked fine, so we
proceeded with the backup.

Then we made sure all installed software was upgraded to the newest releases of
debian 9:

```
sudo apt-get update
sudo apt-get upgrade
sudo apt-get dist-upgrade
```

After that we ran `sudo dpkg -C`, `sudo apt-mark showhold` and `dpkg --audit`
to check whether there were inconsistencies or other problems. They returned
none.

Then we edited the apt sources:

```
sudo sed -i 's/stretch/buster/g' /etc/apt/sources.list
sudo sed -i 's/stretch/buster/g' /etc/apt/sources.list.d/zerotier.list
sudo sed -i 's/stretch/buster/g' /etc/apt/sources.list.d/rspamd.list
```

Then we ran `sudo apt update` to check whether all sources had switched to
buster, and `sudo apt list --upgradable` to learn what packages would be
upgraded.

We issued the upgrade with `sudo apt upgrade`. It showed us a `less` document
with changes, but unfortunately we clicked it away too quickly. After that it
ran through, and notified us of several issues/asked us which config file
version to keep:

- when upgrading postfix, it told us that several `mua_*_sender_restrictions`
  were not available anymore. We need to fix this some time later.
- Also when upgrading bash, it showed us, that the `/etc/bash.bashrc` file was
  modified. At the end of the file `/usr/sbin` was added to path. We will
  upgrade to the default file and modify it, when nessecary with `echo "export
  PATH=/usr/sbin:$PATH" >> /etc/bash.bashrc`
- in /etc/nginx/nginx.conf the ssl_protocols config option was overwritten by
  the upgrade.
- in /etc/ssh/sshd_config the config option `PermitUserEnvironment yes` was
  overwritten.
- /etc/kernel/postinst.d/unattended-upgrades was deleted and created again. We
  used the maintainers version. same for /etc/apt/50unattended-upgrades
- ! We encountered an error when upgrading /var/run/opendkim: `Line references
  path below legacy directory /var/run/, updating /var/run/opendkim →
  /run/opendkim; please update the tmpfiles.d/ drop-in file accordingly.`

While we had a complete meltdown and had to purge and reinstall opendkim, we
reconfigured opendkim to use inet port 8892 instead of a socket file. We
committed the changes to etckeeper: `sudo etckeeper commit "complete meltdown
of opendkim during upgrade, had to reinstall and reconfigure."`

Finally we could run `sudo apt dist-upgrade` and complete the upgrade. Now we
only had to re-edit the overwritten configs.

In the end I restored the config files which were overwritten by the upgrade,
and committed it to etckeeper with `sudo etckeeper commit "Restored the config
options which were overwritten by the upgrade"`.

## Reinstalling mailadm as mailadm2 user

Author: missytake@systemli.org

On 2021-01-19 we realized that because of the upgrade mailadm broke - the
python version had changed from 3.5 to 3.7.

So I decided to reinstall mailadm. The modified install script still was at
`/root/mailadm/install_mailadm.sh`.

First I backed up the databases and cleaned up the old installation:

```
cp /var/lib/mailadm2/mailadm.db .
cp /var/lib/mailadm2/virtual_mailboxes.db .
cp /var/lib/mailadm2/virtual_mailboxes .
sudo systemctl stop mailadm-web.service
sudo rm /var/lib/mailadm2/venv/ -r
```

Then I logged in as root with `sudo su -l root && cd mailadm`. I ran `sh
install_mailadm.sh` to reinstall mailadm with the same config parameters as we
had chosen in
https://github.com/deltachat/sysadmin/tree/master/testrun.org#installing-mailadm-tool-for-mailadm2.

In the end I restarted dovecot & postfix.

To test it, I created a temporary account with an existing token, and sent a
message to myself. It took a few minutes, but in the end it worked. So
everything fine :)

## Lightmeter

We set up lightmeter on testrun.org. It's monitoring our mail logs and
notifying us about issues. It has an overview web interface.

You can access the web interface through SSH forwarding:

1. Connect to testrun.org with `ssh -L 8080:localhost:8080 testrun.org`
2. Open http://localhost:8080 in your browser
3. Login. The credentials are in the git crypt secrets. You can ask
   missytake@systemli.org if you need access.

### Installation

We downloaded the lightmeter binaries like documented in
https://gitlab.com/lightmeter/controlcenter#install-from-binaries:

```
wget https://dl.bintray.com/lightmeter/controlcenter/lightmeter-linux_amd64-1.6.0
chmod +x lightmeter-linux_amd64-1.6.0
sudo mv lightmeter-linux_amd64-1.6.0 /usr/local/bin/lightmeter
lightmeter --help
```

This printed the help message, proving that the install worked. We also created
a folder as a workspace and tried again:

```
sudo mkdir /var/lib/lightmeter_workspace
lightmeter -watch_dir /var/log/ -workspace /var/lib/lightmeter_workspace -listen 8080
```

This threw some file access errors, so we decided to create an own user for
lightmeter with `sudo adduser lightmeter`. We gave it the workspace folder, so
the program could work with `sudo chown lightmeter:lightmeter
/var/lib/lightmeter_workspace`.

Lightmeter needs read access to some logs which were owned by root:adm. These
log files are readable by lightmeter:

- mail.log
- mail.warn
- mail.err

So we gave them to the lightmeter group:

```
sudo chown root:lightmeter /var/log/mail.log
sudo chown root:lightmeter /var/log/mail.warn
sudo chown root:lightmeter /var/log/mail.err
```

Now we only had to add the users who had previously had access to these log
files to the lightmeter group:

```
sudo adduser hpk lightmeter
sudo adduser deltabot lightmeter
```

### Initial Setup

Then we connected to the lightmeter dashboard on testruns localhost with ssh
port forwarding with:

```
ssh -L 8080:localhost:8080 missytake@testrun.org
```

And could open the dashboard on the localhost of our machine in our browser.
After beeing happy, that it works we created an admin account.

In the settings, we enabled email notifications and added testrun.org as an
email address. Unfortunately we couldn't test the mail notifications and the
graphics didn't show anything yet.

### Creating a systemd service

**todo**

