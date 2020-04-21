#!/bin/sh
# This is run by a cron job.

# Set password:
export BORG_PASSPHRASE='pass -c delta/hq4/hetzner-backup'
# Stop services
service apache2 stop
service mysql stop
service dovecot stop
service postfix stop
service unattended-upgrades stop
service ssh stop
# Backup the files to the remote server
borg create --stats --progress --compression lzma hetzner-backup:backups/hq4::'backup{now:%Y-%m-%d-%H}' \
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
service apache2 start
service mysql start
service dovecot start
service postfix start
service unattended-upgrades start
service ssh start
# Delete old backups
borg prune --keep-daily=7 --keep-weekly=4 hetzner-backup:backups/hq4
