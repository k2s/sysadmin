# files.testrun.org

files.testrun.org is a service running on `page` (delta.chat), where you can
upload and download files via a curl request.  They are supposed to get deleted
after certain criteria; for now they get deleted after a week.  In the future a
script which looks at the nginx logs is supposed to handle file deletion.

## Created DNS Entries

First I created the necessary DNS entries, pointing to the `page` machine:

```
AAAA    files   2a00:c6c0:0:151:5::41   86400
A       files   37.218.242.41           86400
```

## Installed ngx_http_upload

```
sudo mkdir -p /usr/local/lib/perl
sudo wget -O /usr/local/lib/perl/upload.pm https://raw.githubusercontent.com/weiss/ngx_http_upload/master/upload.pm
sudo apt install libnginx-mod-http-perl
```

Then I modified the NGINX config according to step 3 in [the
docs](https://github.com/weiss/ngx_http_upload#nginx-setup) and committed the
changed to etckeeper.

Finally, I modified `/usr/local/lib/perl/upload.pm` and configured some
variables:

```
my $external_secret = '';
my $uri_prefix_components = 0;
my $file_mode = 0640;
my $dir_mode  = 0750;
my %custom_headers = (
    'Access-Control-Allow-Origin' => '*',
    'Access-Control-Allow-Methods' => 'OPTIONS, HEAD, GET, PUT',
    'Access-Control-Allow-Headers' => 'Authorization, Content-Type',
    'Access-Control-Allow-Credentials' => 'true',
);
```

## Created NGINX config

```
sudo mkdir -p /var/www/files.testrun.org/u/
sudo mkdir -p /var/www/files.testrun.org/state/
sudo chown www-data:www-data /var/www/files.testrun.org -R
cd /etc/nginx/sites-available/
sudo cp testrun.org files.testrun.org
sudo vim files.testrun.org  # made some changes, e.g. ServerName, removed most routes, added upload route
sudo ln -s /etc/nginx/sites-available/files.testrun.org /etc/nginx/sites-enabled/files.testrun.org
sudo certbot --nginx 
# 12: files.testrun.org
# 2: Redirect
```

### Testing the NGINX Config

```
curl -L -X PUT -F 'data=@test' files.testrun.org/asoiudsmafewf
```

This still fails with an internal server error:

```
2020/06/27 14:05:36 [error] 29233#29233: *66789 call_sv("upload::handle") failed: "Undefined subroutine &upload::handle called.", client: 85.xx.xxx.228, server: files.testrun.org, request: "PUT /asoiudsmafewf HTTP/1.1", host: "files.testrun.org"
```

## Delete After a Week

Do uploaded files get a new modified date?

```
sudo sh -c 'echo "0 2 * * * root find /var/www/files.testrun.org/ -mtime +7 -delete" >> /etc/cron.d/delete-old-builds'
```

## Testing

Upload file 
Download file
Look whether file was deleted automatically

