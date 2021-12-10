# dc.develcow.de

author: missytake@systemli.org

dc.develcow.de is a mailcow installation on a managed VPS at servercow. We got
it for testing purposes on 2021-12-08.

The web interface is accessible at https://dc.develcow.de, credentials are in
the git secrets in https://github.com/deltachat/bg-deltachat.

## Adding a domain

On 2021-12-10, I wanted to create the first test accounts for the provider
tests in https://github.com/deltachat/eppdperf. I logged into the web
interface, but I realized we didn't have a domain configured.

So I tried to configure dc.develcow.de as a domain at
https://dc.develcow.de/mailbox#tab-domains, but I got the error that "Domain
cannot match hostname". So we needed a different domain for our develcow.

In the past I had used x.testrun.org for testing purposes as well, so I decided
to set that up.

### DNS Settings

I configured the following DNS records at Hetzner:

```
A	x	5.1.93.58			900
AAAA	x	2a00:f820:417:0:5:1:93:58	600
```

Apart from that, still configured correctly were:

```
CNAME	imap.x	x	900
CNAME	smtp.x	x	900
MX	x	dc.develcow.de.	900
```

### Creating the Domain in mailcow

Then I opened https://dc.develcow.de/mailbox#tab-domains again and clicked on
"Add domain". I entered `x.testrun.org` as domain and chose the default values
for everything else. The I clicked on "Add domain and restart SOGo" to finish.

After a few seconds, the domain was created successfully.

### Adding SPF and DKIM

Then I clicked on "Edit domain" to get the DKIM key. Right at the bottom, there
was a suggestion for the DKIM DNS entry; I copy-pasted it into Hetzner:

```
TXT	dkim._domainkey.x	v=DKIM1;k=rsa;t=s;s=email;p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnVJ7LAnMeZJOVuxg2ZTvKJsAnq58LTWAy/sWB/TZeb5uuUNwfKK1Z9Ci0Yr3WINNhUgthQk8/QkP2lRWtOvP09Fl7dxCqvFb1qhi38wLg0pWvUktKKKc0wNIV2d19NNMs9ZEUetbImmD9nukHXhsHl1nacBWIzMz1n1wOcumWUQ8hWMTMzoeGwAiSGrxiHhDKM3+mYwJWTlzbHEkQ8Ei33N8D19z0FiNFHna5IW7z7D9n+vdaEnCjzyn3XaQlgWJ4bEXfEAj/wXZw8roIGhQQxb3QBrV4fZ1Ak1Nxd5lwbBiKCoYFatjF8pb1AZNTm4AaauSGbn/46pW8ucVcly/YwIDAQAB	600
```

Then I added an SPF record as well:

```
TXT	x	"v=spf1 a:dc.develcow.de -all"	600
```

### Added Test Account

Then I added the test accounts at https://dc.develcow.de/mailbox#tab-mailboxes,
so I could test whether SPF and DKIM were configured correctly. I clicked on
"Add Mailbox", and created an account called spider@x.testrun.org. I saved the
password in
https://github.com/deltachat/bg-deltachat/blob/master/dapsi/test_accounts/all-testaccounts.txt.

I repeated that process for deltatest@x.testrun.org.

To login with thunderbird, I had to specify `dc.develcow.de` as SMTP and IMAP
server.

Then I used the spider account to test whether SPF & DKIM were configured
correctly. I generated a mail address with https://dkimvalidator.com and sent a
mail there; the results showed that everything was fine.

