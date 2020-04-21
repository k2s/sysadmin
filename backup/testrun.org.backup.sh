#!/bin/sh
# This is run by a cron job.

# Set password:
export BORG_PASSPHRASE='pass -c delta/testrun.org/hetzner-backup'
# Stop services
service nginx stop
service ssh stop
service dovecot stop
service postfix stop
service unattended-upgrades stop
service zerotier-one stop
# Is docker running?
startdocker=0
systemctl is-active --quiet docker && startdocker=1
service docker stop
# Backup the files to the remote server
borg create --stats --progress --compression lzma hetzner-backup:backups/testrun.org::'backup{now:%Y-%m-%d-%H}' \
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
service nginx start
service dovecot start
service postfix start
service unattended-upgrades start
service zerotier-one start
# Restart only if they were running before
if [ startdocker = 1 ]; then service docker start; fi
# Delete old backups
borg prune --keep-daily=7 --keep-weekly=4 hetzner-backup:backups/testrun.org
