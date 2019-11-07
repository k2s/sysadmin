#!/bin/sh
# This is run by a cron job.

# Set password:
export BORG_PASSPHRASE='password'
# Stop the container
/var/discourse/launcher stop app
# Backup the container to the remote server
borg create --stats --progress --compression lzma backup:support.delta.chat::'backup{now:%Y-%m-%d-%H}' /var/discourse/shared/standalone
# Restart the container
/var/discourse/launcher start app
# Delete old backups
borg prune --keep-daily=7 --keep-weekly=4 backup:support.delta.chat

