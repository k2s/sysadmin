# b1.delta.chat setup

Author: missytake@systemli.org

holger mostly set up the machine; this isn't documented I think, but the
changes are tracked with etckeeper.

## Logins

I set up an account for 
- missytake
- treefit
- jikstra
- fdroid (without sudo)

I also configured sudo to work without a password as detailed in
https://github.com/deltachat/sysadmin/blob/master/README.md#sudo

## F-Droid Build Environment

During 36c3, to test the F-Droid build, I created an fdroid server docker
container; it is supposed to build the android app, so we can see whether
fdroid is able to build it. As of 2020-01-15 it doesn't work yet.

### Build the fdroid-server Docker Container

I cloned the fdroid-server docker repository to /home/missytake, so I could
make changes to the Dockerfile and build it myself: 

```
git clone https://gitlab.com/fdroid/docker-executable-fdroidserver
cd docker-executable-fdroidserver
sudo docker build -t fdroid-built .
```

### Prepare the Container for Building

I also cloned my fork of the fdroiddata repository, so I could test my changes
to the build instructions. The `docker run` command mounts it into the
fdroid-server container:

```
git clone https://git.links-tech.org/missytake/fdroiddata
```

#### Get the NDK Build Environment

I downloaded the latest Android NDK from
https://developer.android.com/ndk/downloads/, and pushed it to the server with
rsync. There I unzipped it in /home/missytake:

```
unzip android-ndk-r20b-linux-x86_64.zip
```

Later, the `docker run` command mounts it into the build container.

#### Get the config.py

The server needs a config.py file in the fdroiddata repository to run. The
default configuration should be fine:

```
cd fdroiddata
wget https://gitlab.com/fdroid/fdroidserver/raw/master/examples/config.py
```

#### Remove All the Other Build Files

Because they threw errors, I removed all .yml files of the other apps. I
committed it to git, to be able to pull new changes to the repository:

```
cp metadata/com.b44t.messenger.yml ~
rm metadata/*.yml
cp ~/com.b44t.messenger.yml metadata/
git add . 
git config --local user.name "a"
git config --local user.email "a"
git commit -m "removing all the broken files"
git pull origin master
```

#### Accept the Gradle Licenses

If you run the `docker run` build command now, gradle fails, because it needs
some licenses accepted.

(I hope) this is only necessary on the local machine; as the official F-Droid
build server has already accepted those licenses.

It is a bit complicated to setup, because it doesn't seem to be possible to
accept the licenses with the command line.  The recommended workaround is to
accept the licenses in the GUI of Android Studio, and upload the licenses
directory to the server afterwards. The best source for this procedure is:
https://developer.android.com/studio/intro/update.html#download-with-gradle

After I accepted the licenses in the GUI, I copied the license directory to the
server with `rsync -r android-studio/license b1.delta.chat:`.

After that didn't work out either, I decided to setup the fdroid server with
the debian packages instead.

### Trying with the debian packages

```
sudo apt install fdroidserver vagrant
cd fdroiddata
ulimit -n 2048
wget https://gitlab.com/fdroid/fdroidserver/raw/master/makebuildserver
python3 makebuildserver
fdroid build --server com.b44t.messenger:571
```

That didn't work out either. So we tried it with their manual setup script, and
after [this guide instead](https://f-droid.org/en/docs/Build_Server_Setup/).

This helped, and after some fiddling, we got it running with Vagrant and
Virtualbox. Unfortunately it's hard to reproduce and document, but the guide
should help.

### Build Delta Chat Android with the F-Droid build environment

Builds have to be executed by the fdroid user: `sudo su - fdroid`. You should
also `cd fdroiddata` and `git pull origin master` or `git pull upstream
master`, depending on which build instructions you want to try out. You can see
all currently configured remote repositories with `git remote -v`. Add a new
one with `git remote add new-or-so https://gitlab.com/<username>/fdroiddata`.

Before starting the build, you should make sure the build server isn't running
already with `vagrant global-status`. If it is, you can destroy it with `cd
~/fdroiddata/builder && vagrant destroy && cd ..`.

Now take a last look at the metadata file of the deltachat app with `vim
metadata/com.b44t.messenger.yml` to see which versions are available.

To build the latest version, you can now execute `fdroid build --server -v -l com.b44t.messenger`.

## Build Android Nightlys

In March 2020, we set up Android Nightly builds, which you can download at
https://download.delta.chat/android/nightly/.

The setup is documented here:
https://github.com/deltachat/sysadmin/tree/master/download.delta.chat#android-nightlys

## Upgrading b1.delta.chat to Ubuntu 20.04

The guide we used:
https://ubuntu.com/blog/how-to-upgrade-from-ubuntu-18-04-lts-to-20-04-lts-today

First we checked which version was running before the upgrade:

```
$ uname -a
Linux b1 4.15.0-112-generic #113-Ubuntu SMP Thu Jul 9 23:41:39 UTC 2020 x86_64 x86_64 x86_64 GNU/Linux
```

And which services were running:

```
$ sudo service --status-all
 [ + ]  apparmor
 [ + ]  atd
 [ + ]  binfmt-support
 [ - ]  cgroupfs-mount
 [ - ]  console-setup.sh
 [ + ]  cpufrequtils
 [ + ]  cron
 [ - ]  cryptdisks
 [ - ]  cryptdisks-early
 [ + ]  dbus
 [ + ]  docker
 [ + ]  ebtables
 [ + ]  grub-common
 [ + ]  haveged
 [ - ]  hwclock.sh
 [ - ]  keyboard-setup.sh
 [ + ]  kmod
 [ + ]  libvirt-guests
 [ - ]  libvirtd
 [ + ]  loadcpufreq
 [ - ]  lvm2
 [ + ]  lvm2-lvmetad
 [ + ]  lvm2-lvmpolld
 [ - ]  mdadm
 [ - ]  mdadm-waitidle
 [ - ]  nfs-common
 [ - ]  nfs-kernel-server
 [ - ]  pcscd
 [ - ]  plymouth
 [ - ]  plymouth-log
 [ + ]  procps
 [ - ]  redis-server
 [ - ]  rpcbind
 [ - ]  rsync
 [ + ]  rsyslog
 [ + ]  ssh
 [ + ]  ubuntu-fan
 [ + ]  udev
 [ + ]  unattended-upgrades
 [ + ]  uuidd
 [ - ]  virtlogd
 [ + ]  virtualbox
 [ - ]  x11-common
```

Important services are: docker, libvirt, virtualbox, ssh, cron. Also very
important are the android nightlys, which use cron, docker, and virtualbox.

First we tried out the android nightly build, and it ran through fine. I
quickly installed the nightly apk to test if it worked - and it did.

### Run the upgrade

Then we ran `sudo do-release-upgrade -m server --allow-third-party -c` to check
for new versions - it offered us to install Ubuntu 20.04.2 LTS. So we ran `sudo
do-release-upgrade -m server --allow-third-party`, but it asked us to upgrade
to the newest packages of our current distribution first.

So we ran `sudo apt update` and `sudo apt upgrade` first. Then we continued
with `sudo do-release-upgrade -m server --allow-third-party` This time it asked
us for a reboot. We checked that no CI jobs were running, and rebooted with
`sudo systemctl reboot -i`.

After a few minutes the server was up again and we could ssh-login without
problems. We ran `sudo services --status-all` to check whether everything was
fine again, but we had to start uuidd and docker manually with `sudo systemctl
start uuidd docker`. We enabled them with `sudo systemctl enable docker` and
`sudo systemctl enable uuidd`. For uuidd it didn't work to enable it at reboot
- weird, but we can't do much about it :shrug:.

Then we dared to run sudo run `do-release-upgrade -m server
--allow-third-party` again. It told us that a few packages would be removed,
but none of that looked important to us. So we confirmed with `y`.

The ubuntu installation asked us some things, during which and we lost the
terminal session so we had to figure out, how to resume the installation -
first we killed the old process with `kill 10664` to get rid of the dpkg lock,
then we could continue the upgrade process with `sudo dpkg --configure -a`.
During the upgrade process we were asked to integrate maintainer changes to
config files into our configuration; we had to touch
`/etc/systemd/resolved.conf`, `/etc/ssh/sshd_config`, and
`/etc/libvirt/qemu.conf`. At some point the upgrade completed.
https://askubuntu.com/questions/346678/how-do-i-resume-a-release-upgrade

After accepting incoming changes and replacing our `/etc/ssh/sshd_config` file,
we disabled ssh password login, so you can only login with a public key.

After the upgrade, we tried to build the android nightlys - and it worked out
of the box! So we can proudly claim that the upgrade went (almost) flawlessly.
 
## Secure SSH Access

Author: missytake@systemli.org

On 2021-04-23, we realized that SSH was not protected after the best practices.
So I installed sshguard with `sudo apt install sshguard`. The default config
seemed fine, so I didn't touch anything.

