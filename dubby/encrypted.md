# Howto: encrypt a dedicated Debian 10 Server on Hetzner (dubby)
This will help you create an encrypted dedicated Server. On Startup/restart of the system you will have to connect to busybox and decrypt the volume containing the system. We will use the Hetzner [installimage script](https://docs.hetzner.com/robot/dedicated-server/operating-systems/installimage/). To use this guide you should be familiar with ssh and partitioning drives on os installation.

This guide relies on:

https://github.com/TheReal1604/disk-encryption-hetzner/blob/master/debian/debian_swraid_lvm_luks.md

#### Used hardware:
   Disk /dev/nvme0n1: 1024 GB (=> 953 GiB) 

   Disk /dev/nvme1n1: 1024 GB (=> 953 GiB) 

   Total capacity 1907 GiB with 2 Disks

### Activate Hetzner Rescue System
You can do this in the rescue tab of the robot-your-server webinterface. This will lauch an image from hetzner on the machine and give you a password with which you can e.g chroot into your installation. We will use it to partition our drive and Install debian 10. Then we can create an encrypted volume and move our fresh installation into it.

### Hetzner installscript (when in resuce system)
```
$ vim /autosetup
```
/autosetup:
```
##  Hetzner Online GmbH - installimage - config

DRIVE1  /dev/nvme0n1
DRIVE2  /dev/nvme1n1
##  SOFTWARE RAID:
## activate software RAID?  < 0 | 1 >
SWRAID 1
## Choose the level for the software RAID < 0 | 1 | 10 >
SWRAIDLEVEL 1
##  BOOTLOADER:
BOOTLOADER grub
##  HOSTNAME:
HOSTNAME dubby
##  PARTITIONS / FILESYSTEMS:
PART /boot  ext3     512M
PART lvm    vg0       all
LV vg0   swap   swap     swap         4G
LV vg0   root   /        ext4         10G
##  OPERATING SYSTEM IMAGE:
IMAGE /root/images/Debian-105-buster-64-minimal.tar.gz
```
```
$ installimage
$ reboot
$ apt update
$ apt dist-upgrade
$ apt clean
$ reboot
```

### install busybox and dropbear
This will give you the ability to first boot busybox for decryption and then start from decrypted volume.

```
$ apt install busybox dropbear-initramfs dropbear*
$ apt clean
$ vim /etc/initramfs-tools/initramfs.conf
```
/etc/initramfs-tools/initramfs.conf:
```
BUSYBOX=y
```

### Handle ssh key for busybox login

>Only rsa ssh-keys will work for decryption (please use 4096 bits when creating a key for decryption ;)

```
$ chmod 600 ~/.ssh/authorized_keys
$ cp ~/.ssh/authorized_keys /etc/dropbear-initramfs/authorized_keys
```

### Start Hetzner rescue system again
```
$ reboot
$ vgscan -v
$ vgchange -a y
$ mount /dev/mapper/vg0-root /mnt
```
stop rsync and backup the existing Debian installation
```
$ echo 0 >/proc/sys/dev/raid/speed_limit_max
$ mkdir /oldroot
$ cp -a /mnt/. /oldroot/.
$ echo 800000 >/proc/sys/dev/raid/speed_limit_max
```
unmount installation
```
$ umount /mnt
```
delete not encrypted LVM-Volume-Group
```
$ vgremove vg0
```
Encrypt drive. You will be asked for a password. The password is best to be generated and stored with a password manager. We use git-crypt to share passwords.
```
$ cryptsetup --cipher aes-xts-plain64 --key-size 256 --hash sha256 --iter-time=10000 luksFormat /dev/md1
$ cryptsetup luksOpen /dev/md1 cryptroot
$ pvcreate /dev/mapper/cryptroot
$ vgcreate vg0 /dev/mapper/cryptroot
$ lvcreate -n swap -L4G vg0
$ lvcreate -n root -l 100%FREE vg0
$ mkfs.ext4 /dev/vg0/root
$ mkswap /dev/vg0/swap
```
mount encrypted volume
```
$ mount /dev/vg0/root /mnt
```
stop rsync again and recover the debian installation
```
$ echo 0 >/proc/sys/dev/raid/speed_limit_max
$ cp -a /oldroot/. /mnt/.
$ echo 800000 >/proc/sys/dev/raid/speed_limit_max
```
mount final installation
```
$ mount /dev/md0 /mnt/boot
$ mount --bind /dev /mnt/dev
$ mount --bind /sys /mnt/sys
$ mount --bind /proc /mnt/proc
$ mkdir /mnt/run/udev
$ mount --bind /run/udev /mnt/run/udev
$ chroot /mnt
$ vim /etc/crypttab
```
/etc/crypttab:
```
## <target name> <source device>         <key file>      <options>

cryptroot /dev/md1 none luks
```

### finalize the installation
```
$ update-initramfs -u
```
rewrite grub
```
$ update-grub
$ grub-install /dev/nvme0n1
$ grub-install /dev/nvme1n1
```

### unmount final installation
```
$ exit
$ umount /mnt/boot /mnt/proc /mnt/sys /mnt/dev /mnt/run/udev
$ umount /mnt
$ sync
$ reboot
```

## login to busybox and decrypt
```
$ ssh -o UserKnownHostsFile=/dev/null root@<your ip>
$ cryptroot-unlock
```
Congrats! When you enter the Password, the system should restart and you should be able to ssh into your freshly installed system.
