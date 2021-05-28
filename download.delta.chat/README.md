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

## Android Nightlies

Android Nightly builds available at
https://download.delta.chat/android/nightly/ are built by Concourse CI installed
on `b1.delta.chat`.  Concourse CI setup is documented in `b1.delta.chat` directory.

Pipeline configuration is committed to this directory (`nightlies.yml`) and can be installed onto Concourse CI server with
```
fly -t b1 set-pipeline -p nightlies -c nightlies.yml -l secret.yml
```
where `secret.yml` is a file containing SSH key used to upload nighties via `rsync`:
```
download.delta.chat:
  private_key: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    <skipped>
    -----END OPENSSH PRIVATE KEY-----
```
