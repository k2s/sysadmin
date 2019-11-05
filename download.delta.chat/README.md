# How to use download.delta.chat

Author: compl4xx@testrun.org

To find out how this server was set up, see delta.chat/README.md in this
repository.

## Pushing desktop preview builds

This document tells a story on how I configured the desktop preview builds to
be automatically pushed to download.delta.chat.  This will serve both as an
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
find /var/www/html/download/desktop/preview/ -size 53c -delete
sudo etckeeper commit "cronjob to delete desktop builds"
```

It's executed every 10 minutes.

## Android

we need to create own workflow for this




