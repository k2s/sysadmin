#!/bin/sh
# This is run by a cron job.

# Set password:
export BORG_PASSPHRASE='pass -c delta/page/hetzner-backup'
# Stop services
service nginx stop
service ssh stop
# Backup the files to the remote server
borg create --stats --progress --compression lzma hetzner-backup:backups/page::'backup{now:%Y-%m-%d-%H}' \
        /                                    \
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
service nginx start
service ssh start
# Delete old backups
borg prune --keep-daily=7 --keep-weekly=4 hetzner-backup:backups/page


