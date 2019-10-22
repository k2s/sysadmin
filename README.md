# Setup page VM for delta.chat & download.delta.chat

This is how I set up the VM for delta.chat & the download page. The reasons
were to migrate away from netlify, and to have a download space where we can
push deliverables in automated release scripts.

## Create the VPS

The VPS is running at greenhost.nl. I selected the following parameters during
VPS creation:

* 2 GB Ram
* 1 CPU
* 200 GB Disk Space
* Location: Amsterdam
* OS only: Debian 9 (stretch)
* SSH key: emil
* Hostname: page
* Advanced options: enable API (not sure whether we need it)

It told me to login with `ssh root@37.218.242.41`.

## Setting up Users

I first executed `apt update && apt upgrade -y` to bring the server up-to-date.
Then I installed vim and man.

I created an `emil` user and added it to the `sudo` group.

When I played around with sudo, it always gave me the following error: `sudo:
unable to resolve host page`. Because that was odd, I added the following line
to `/etc/hosts`:

```
127.0.1.1	page
```

The error stopped appearing afterwards.

## SSH config

First I copied `/root/.ssh/authorized_keys` to
`/home/emil/.ssh/authorized_keys`, and tested it, to make sure I could login as
the emil user.

Then I edited the SSH config to forbid root login, change the port to 42022,
and forbid password login, to secure the server.

But when I tested it, I received a connection timeout for port 42022. I set it
back to 22, and it worked again; the login message told me that the firewall
only allows the ports 22, 80, and 443. Fine, then we'll just use the normal
port, I guess. At least the usernames aren't as easy to guess, and root is
forbidden.

A copy of the `/etc/ssh/sshd_config` file is in this repository.

## Further Server Configuration


## Setting up nginx + jekyll

Source: http://briancain.net/using-jekyll-and-nginx/

