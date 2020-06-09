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
specify `x.testrun.org` as IMAP & SMTP server manually.

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

