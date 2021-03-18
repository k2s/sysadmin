# Sysadmin Collective

This is the documentation of the Delta Chat sysadmin collective. 

You can contact us at: 

In the folders, you can find the documentation of how our services are set up.
This document describes some of our best practices and high-level ideas.

## Best Practices

### SSH

Shell login is protected by SSH. We allow login only with a public key, not
with a password. You can't login as root. The port is 22. Everyone gets their
own user for login.

You need to save the password of at least one user with sudo rights. This way,
you can recover from a bad SSH configuration through login via the web
interface. (at least that's possible with greenhost and hetzner).

For the other users, the password can be a long random string, they won't need
it anyway.

### sudo

As you don't need/can't use a password for login, sudo is password-less as
well.

### etckeeper

All changes in the server config should be tracked with etckeeper. This way,
others can follow the changes you make. Good commit messages are important.

### tmux

To be able to work on things together, we are using tmux. We share a user,
which automatically starts a tmux session at login, or attaches itself to the
existing tmux session if there exists one. This happens through these lines in
.profile:

```
# autostart tmux
if [ -t 0 -a -z "$TMUX" ]
then
        test -z "$(tmux list-sessions)" && exec tmux new -s "$USER" || exec tmux new -A -s $(tty | tail -c +6) -t "$USER"
fi
```

The escape key is `ctrl+a`. You can quit (detach yourself from the session) by
first pressing `ctrl+a` and then `d`. Useful commands:

```
c: create a new tab
n: switch to the next tab
p: switch to the previous tab
d: detach
```

### Backup & Restore

We have full backups of each server each night, which can be restored quickly.
They are done with borgbackup scripts, to a Hetzner backup space.

Restore is only tested for support.delta.chat. You can follow this example if
you need to restore this or another service:
https://github.com/deltachat/sysadmin/tree/master/backup#restore-migration-to-hetzner-cloud

