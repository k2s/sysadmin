# support.delta.chat Discourse Instance

This Discourse instance was set up by compl4xx@systemli.org. If something does
not work as expected, you can ask them what they did wrong.

I resized the disk image of this VM to 15 GB.

I then followed this setup guide for discourse, from this point on:
https://web.archive.org/web/20180420170222/https://github.com/discourse/discourse/blob/master/docs/INSTALL-cloud.md#install-discourse

The settings I chose during the setup script are in the secrets folder of the
private OTF repo, protected by git-crypt.

After the installation, I added the discourse-solved plugin:
https://meta.discourse.org/t/discourse-solved-accepted-answer-plugin/30155

## Update settings

On 2018-10-02, we had to update the e-mail settings because of a mail provider
change. The new settings are in the secrets folder as well.

I changed them in /var/discourse/containers/app.yml and updated them by
rebuilding the container with `./launcher rebuild app`.

## Backup

You can just backup and restore the whole docker container very easily:
https://meta.discourse.org/t/backup-discourse-from-the-command-line/64364

The backup server is defined in `/root/.ssh/config` as `backup`, so you can
refer to it like that in scripts which are executed by root.

I created a borg test repository:

```
borg init backup:support.delta.chat --encryption=repokey
```

Backups are encrypted with a passphrase. You can find it in the secrets folder
in the OTF repo as well. To backup the whole container into the test repo:

```
export BORG_PASSPHRASE='password'
/var/discourse/launcher stop app
borg create --stats --progress --compression lzma backup:support.delta.chat::'backup{now:%Y%m%d}' /var/discourse/shared/standalone
/var/discourse/launcher start app
borg prune --keep-daily=7 --keep-weekly=4 backup:support.delta.chat
```

There are backups kept from the last 7 days, and 1 of every last 4 weeks.

## Restore

Backups are encrypted with a passphrase. Secrets folder, look above. To
restore the whole container from the test repo:

```
export BORG_PASSPHRASE='password'
/var/discourse/launcher stop app
rm -rf /var/discourse/shared/standalone
cd /
borg extract backup:support.delta.chat::thebackupyouwant
/var/discourse/launcher start app

## Maintenance: storage driver

In September 2019, suddenly the /var/discourse/launcher script complained about
the docker storage driver (overlay2), which apparently wasn't supported by
discourse anymore:

```
Your Docker installation is not using a supported storage driver. If we were to proceed you may have a broken install.
aufs is the recommended storage driver, although zfs/btrfs/overlay and overlay2 may work as well.
Other storage drivers are known to be problematic.
You can tell what filesystem you are using by running "docker info" and looking at the 'Storage Driver' line.

If you wish to continue anyway using your existing unsupported storage driver,
read the source code of launcher and figure out how to bypass this check.
```

According to [this forum
post](https://meta.discourse.org/t/cant-run-launcher-rebuild-app-docker-storage-driver-is-unsupported/56927/2)
a new storage driver was needed. First I shut down the container manually with
`sudo docker stop app` and executed `/var/discourse/backup.sh`, to make sure we
had a consistent, recent backup.

Then I added a custom dockerd config file in
`/lib/systemd/docker.service.d/docker.conf` with the following content:

```
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --storage-driver=aufs
```

Then I also created `/etc/docker/daemon.json`:

```
{
  "storage-driver": "aufs"
}
```

After which the docker daemon failed at restart. Finally, `journalctl -xe` told
me that the aufs storage driver isn't installed, and [the
Internet](https://stackoverflow.com/questions/37110291/how-to-enable-aufs-on-debian)
even said that it is not supported anymore by modern kernels.

As overlay2, the currently installed storage driver, was recommended everywhere
as the better solution (and is even the discourse people's second favorite), I
decided to just use overlay2. I removed my prior modifications again.

### Upgrading to get out of this mess

Discourse asked me to do this to upgrade the discourse instance to a new version:

```
cd /var/discourse
git pull
./launcher rebuild app
```

Afterwards, the launcher script didn't complain about the storage driver
anymore - apparently updating it with `git pull` sorted out the warning.

## Plugins

Over the years, I installed 2 plugins to this discourse instance:

- solved-checkbox: https://github.com/discourse/discourse-solved
- sitemap: https://github.com/discourse/discourse-sitemap

### Installing a Plugin

Source: https://meta.discourse.org/t/install-plugins-in-discourse/19157

I installed both plugins by adding a line to `/var/containers/app.yml` with the
command to clone the plugin into a certain directory, like this:

```
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/discourse/docker_manager.git
          - git clone https://github.com/discourse/discourse-solved.git
          - git clone https://github.com/discourse/discourse-sitemap.git
```

The docker_manager plugin came pre-installed.

Afterwards I rebuilt the container with `sudo /var/discourse/launcher rebuild
app` to actually install it in the container.

