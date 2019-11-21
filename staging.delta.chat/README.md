# staging.delta.chat

If you have questions: compl4xx@systemli.org

staging.delta.chat is used so you can preview changes if you have opened a pull
request to https://github.com/deltachat/deltachat-pages.

It works like this:

- On https://staging.delta.chat, you can see a list of all open (& closed) PRs.
  You can use the link to access their preview.
- The link gets displayed in the PR checks as well, through a GitHub action.
- When a PR gets closed or merged, the preview gets replaced with a file which
  says that it's outdated and has been removed.

For documentation on how staging.delta.chat was set up, see
https://github.com/deltachat/sysadmin/tree/master/delta.chat#staging

