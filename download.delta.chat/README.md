# How to use download.delta.chat

Author: compl4xx@testrun.org

To find out how this server was set up, see delta.chat/README.md in this
repository.

## Pushing desktop preview builds

This document tells a story on how I configured the desktop preview builds to
be automatically pushed to download.delta.chat. This will serve both as an
example on how to use this service, as well as documentation how I did it.

The clue are GitHub actions - they are basically executing the build job and do
the copying. The changes I am talking about are in
https://github.com/deltachat/deltachat-desktop/pull/1088.

### Change application metadata before build

One thing we wanted to do was to change some variables in package.json before
build. This way, you can have a preview build installed next to a stable
version on the same OS, without them conflicting too much.

The variables we wanted to change:
* name: "deltachat-desktop" -> "deltachat-desktop-dev"
* ProductName: "DeltaChat" -> "DeltaChat-DevBuild"

treefit wrote a small node.js script which takes care of the rename and is
executed by a GitHub action.

### Copy the file to download.delta.chat

We chose
https://download.delta.chat/desktop/preview/deltachat-desktop-$branch.AppImage
as an example download path - the branches don't get a folder of their own,
because scp isn't easily able to create folders, and we would need to give the
SSH key more permissions.

So treefit modified the GitHub action to rename the deliverables before upload,
so they had the branch name in the filename, and were distinguishable from
other deliverables.

To copy the built files, treefit used the scp action we knew from the
deltachat-pages repository.

I also added the server's user name and the private key to the GitHub secrets,
so GitHub can actually execute the script.

### Post download link to PR

To make the preview build available for PR contributors and reviewers, I also
included a small GitHub action which replies to the PR with the link to the
downloadable executable files. This way, they are easily accessible.

Again I chose the workflows from deltachat-pages as an example.

#### Posting download links to check details instead

Later we decided that comments were to noisy. Instead we posted the links to
the details of checks, via the GitHub statuses API. This is done in the GitHub
build action with curl requests:
https://github.com/deltachat/deltachat-desktop/pull/1116/files

### Delete builds from closed PRs

The download.delta.chat VM has 200GB of space, too small to keep all the
preview builds from the past. So I wrote another GitHub workflow to replace the
outdated builds with small files which say "This preview build is outdated and
has been removed." 

They would still have the old filename, including the file ending, which is not
intuitive for a text file and generally ugly.

#### Cron job to delete the overwrite-text files

Source: https://stackoverflow.com/questions/27789254/shell-script-to-delete-files-smaller-than-x-kb

To delete the 53 byte small overwrite files, I added a cronjob at
/etc/cron.d/delete-old-builds, and commit it with etckeeper:

```
*/10 * * * * root find /var/www/html/download/desktop/preview/ -size 53c -delete
sudo etckeeper commit "cronjob to delete desktop builds"
```

It's executed every 10 minutes.

### Desktop Autoindex

Author: missytake@systemli.org

On 2019-12-11, treefit asked to be able to browse all released desktop clients.
I extended the autoindex rule for /desktop/preview/ to /desktop/, reloaded the
nginx config, and committed it to etckeeper.

## Android

I added a workflow for pushing apk builds to the Android Release checklist:
https://github.com/deltachat/deltachat-android/blob/master/docs/release-checklist.md#release-new-apk-and-play-store-version

It included a symbolic link at
`/var/www/html/download/android/deltachat-stable.apk`, which pointed to the
most recent version and was supposed newly created and pushed with rsync at
every release.

The first time r10s tried out the commands from the checklist, they failed, so
I had to make adjustments to the steps on 2019-12-05.

hpk suggested to make the folder listing available as a permalink, instead of
offering the symbolic link, because "stable" was a misnamer; so I changed the
nginx config to make that possible, changed the link at
https://delta.chat/download, and removed the symbolic link.

## Android Nightlys

On 2020-03-18, I started to setup an automated Android nightly build.

### Initial Build

I used the fdroid user on b1.delta.chat for this, as it's already used for
building the app. I added it to the `docker` group with `sudo adduser fdroid docker`.

I followed the build instructions on
https://github.com/deltachat/deltachat-android/#build-using-dockerfile, Docker
was already installed on the machine. They worked, it generated an apk in
`/home/fdroid/deltachat-android/build/outputs/apk/gplay/debug/deltachat-gplay-debug-1.2.1.apk`.
I downloaded it with scp and installed it with `adb install` next to my other 3
Delta Chat apps, it worked fine.

### Automating the Build

Then I wrote a short build script, which is located at
`/home/fdroid/build-nightly.sh`.

This script is executed each night at 02:30 AM by the fdroid user in this
cronjob, which I added to `/etc/cron.d/android-nightly`:

```
30 2 * * * fdroid /home/fdroid/build-nightly.sh
```

### Pushing the Build to download.delta.chat

To be able to push nightly builds to download.delta.chat, I generated a new SSH
key for the fdroid user on b1.delta.chat with `ssh-keygen -t ed25519`. I saved
the private key in the secrets directory in the otf repo.

Then on download.delta.chat, I added the `android-nightly` user with the
following command: `sudo adduser android-nightly`. I specified a loooong
password which is not meant to be used.

I added the ssh public key to `/home/android-nightly/.ssh/authorized_keys`, so
files could be pushed to this server:

```
sudo mkdir /home/android-nightly/.ssh
sudo vim /home/android-nightly/.ssh/authorized_keys
sudo chown android-nightly:android-nightly -R /home/android-nightly/.ssh
```

I also had to limit access of the key to scp and rsync, with the rssh tool.
I set it up like this:

```
sudo chsh -s /usr/bin/rssh android-nightly
cd /home/android-nightly
sudo chmod u-w * -R
sudo chmod u-w .* -R
```

And finally I created a directory for the nightly uploads and changed the owner
to android-nightly:

```
sudo mkdir /var/www/html/download/android/nightly/
sudo chown android-nightly:android-nightly /var/www/html/download/android/nightly/
```

Then I added the rsync command to the script and tried it out - it worked
marvellous.

Three problems were left:

- The cronjob wasn't working correctly, and couldn't mail the debug output
  anywhere, because there was no MTA set up on b1.delta.chat.
- The script created a lot of containers without removing them afterwards.
- By using podman instead of docker, it should be possible to run the build
  without basically root rights - the fdroid user doesn't need those
  privileges.

### Removing Old Build Containers

First I did an `apt update && apt upgrade -y` to get a recent version of
docker. Then I removed dangling containers with `docker containers prune`.

Finally I could change the script so it would remove the containers after each
run.

### Using Podman Instead of Docker

Now I wanted to exchange docker with podman so I could remove fdroid from the
docker UNIX group.

To install podman, I added a source to the apt list:

```
. /etc/os-release
sudo sh -c "echo 'deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /' > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list"
wget -nv https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/xUbuntu_${VERSION_ID}/Release.key -O- | sudo apt-key add -
sudo apt-get update -qq
sudo apt-get -qq -y install podman
```

Then I replaced the docker calls in the script with "podman", and copied the
script to this repository again.

It didn't work initially, so I decided to remove my copy of the
deltachat-android repository and clone it again. Then I tried it again:

```
sudo rm ../fdroid/deltachat-android -rf
git clone https://github.com/deltachat/deltachat-android
./build-nightly.sh
```

This produced an error first as well, because there was no build of the
deltachat-android container existing. I commented it out, as it wasn't needed
anymore anyway. It didn't help, I just ran into more errors.

Soon I lost patience and thought that the time to solve this was not worth it.
I redid the changes to the script and uninstalled podman:

```
sudo rm /etc/apt/sources.list.d/devel\:kubic\:libcontainers\:stable.list
sudo apt remove podman
sudo apt update
```

A new run of the build-nightly.sh script went wrong, because I hadn't used the
`--recursive` flag when cloning the repository. I fixed it quickly and tried
again:

```
rm -rf deltachat-android/
git clone https://github.com/deltachat/deltachat-android --recursive
./build-nightly.sh
```

With ndk-make && gradlew, it didn't work, because gradlew didn't find the SDK.
This was not a problem with two separate commands, where the build succeed.
Leaving the problem, that I couldn't add the --rm flag to the first docker run
command. 

So after the script there was a dangling container. I added another docker rm
command to remove that container; now the script was good so far, and ran
without leaving behind any unnecessary containers.

### Fix Cronjob

To get the cronjob output, I followed this quick quide:
https://www.thegeekstuff.com/2012/07/crontab-log/

Afterwards, the build job ran without problems, and the build was uploaded to
https://download.delta.chat/android/nightly/2020-03-21/

### Delete Outdated Nightly Builds

tbd

