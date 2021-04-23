# Dubby.org is a high performance host

Specs:
- 16 cores
- 64gb RAM
- 2 TB NVME

Dubby was set up by Janek and is currently idling. It could serve as CI/Bots host.
If we dont find a suitable purpose we will give up dubby.

Services:
- Email: Setup like merlinux.eu(hq6) See https://github.com/deltachat/sysadmin/tree/master/merlinux.eu

## Secure SSH Access

Author: missytake@systemli.org

On 2021-04-23, we realized that SSH was not protected after the best practices.
So I installed sshguard with `sudo apt install sshguard`. The default config
seemed fine, so I didn't touch anything.

