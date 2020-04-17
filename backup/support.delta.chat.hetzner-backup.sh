#!/bin/sh
# This is run by a cron job.

# Set password:
export BORG_PASSPHRASE='pass -c delta/support.delta.chat/hetzner-backup'
# Stop the container
/var/discourse/launcher stop app
# Stop services
service docker stop
service exim4 stop
# Backup the files to the remote server
borg create --stats --progress --compression lzma hetzner-backup:backups/support.delta.chat::'backup{now:%Y-%m-%d-%H}' \
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
service exim4 start
service docker start
# Restart the container
/var/discourse/launcher start app
# Delete old backups
borg prune --keep-daily=7 --keep-weekly=4 hetzner-backup:backups/support.delta.chat


