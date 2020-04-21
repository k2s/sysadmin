#!/bin/sh
# This is run by a cron job, as the missytake user.

# Set password:
export BORG_PASSPHRASE='pass -c delta/login.testrun.org/backup'
# Stop sudo services
sudo service ssh stop
sudo service nginx stop
sudo service unattended-upgrades stop
forever stopall
# Backup the files to the remote server
sudo -E borg create --stats --progress --compression lzma hetzner-backup:backups/login.testrun.org::'backup{now:%Y-%m-%d-%H}' \
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

# Restart sudo services
sudo service ssh start
sudo service nginx start
sudo service unattended-upgrades start
cd /home/missytake/discourse-login-bot/ && forever start src/index.js
# Delete old backups
borg prune --keep-daily=7 --keep-weekly=4 hetzner-backup:backups/login.testrun.org
