#!/bin/sh
# This is run by a cron job.

# Set password:
export BORG_PASSPHRASE='pass -c delta/b1/hetzner-backup'
# Stop services
service docker stop
service ssh stop
# Is libvirtd running?
startlibvirtd=0
systemctl is-active --quiet libvirtd && startlibvirtd=1
service libvirtd stop
# Is virtualbox running?
startvirtualbox=0
systemctl is-active --quiet virtualbox && startvirtualbox=1
service virtualbox stop
# Backup the files to the remote server
borg create --stats --progress --compression lzma hetzner-backup:backups/b1::'backup{now:%Y-%m-%d-%H}' \
        /                                    \
        --exclude /home/ci/ci_builds         \
        --exclude /dev                       \
        --exclude /proc                      \
        --exclude /sys                       \
        --exclude /var/run                   \
        --exclude /run                       \
        --exclude /lost+found                \
        --exclude /mnt                       \
        --exclude /media                     \
        --exclude /var/lib/lxcfs

# Restart services
service ssh start
service docker start
# Restart only if they were running before
if [ startlibvirtd = 1 ]; then service libvirtd start; fi
if [ startvirtualbox = 1 ]; then service virtualbox start; fi
# Delete old backups
borg prune --keep-daily=7 --keep-weekly=4 hetzner-backup:backups/b1
