# b1.delta.chat setup

Author: missytake@systemli.org

holger mostly set up the machine; this isn't documented I think, but the
changes are tracked with etckeeper.

## Logins

I set up an account for 
- missytake
- treefit
- jikstra

I also configured sudo to work without a password as detailed in
https://github.com/deltachat/sysadmin/blob/master/README.md#sudo

## F-Droid Build Environment

During 36c3, to test the F-Droid build, I created an fdroid server docker
container; it is supposed to build the android app, so we can see whether
fdroid is able to build it. As of 2020-01-15 it doesn't work yet.

### Build the fdroid-server Docker Container

I cloned the fdroid-server docker repository to /home/missytake, so I could
make changes to the Dockerfile and build it myself: 

```
git clone https://gitlab.com/fdroid/docker-executable-fdroidserver
cd docker-executable-fdroidserver
sudo docker build -t fdroid-built .
```

### Prepare the Container for Building

I also cloned my fork of the fdroiddata repository, so I could test my changes
to the build instructions. The `docker run` command mounts it into the
fdroid-server container:

```
git clone https://git.links-tech.org/missytake/fdroiddata
```

#### Get the NDK Build Environment

I downloaded the latest Android NDK from
https://developer.android.com/ndk/downloads/, and pushed it to the server with
rsync. There I unzipped it in /home/missytake:

```
unzip android-ndk-r20b-linux-x86_64.zip
```

Later, the `docker run` command mounts it into the build container.

#### Get the config.py

The server needs a config.py file in the fdroiddata repository to run. The
default configuration should be fine:

```
cd fdroiddata
wget https://gitlab.com/fdroid/fdroidserver/raw/master/examples/config.py
```

#### Remove All the Other Build Files

Because they threw errors, I removed all .yml files of the other apps. I
committed it to git, to be able to pull new changes to the repository:

```
cp metadata/com.b44t.messenger.yml ~
rm metadata/*.yml
cp ~/com.b44t.messenger.yml metadata/
git add . 
git config --local user.name "a"
git config --local user.email "a"
git commit -m "removing all the broken files"
git pull origin master
```

#### Accept the Gradle Licenses

If you run the `docker run` build command now, gradle fails, because it needs
some licenses accepted.

(I hope) this is only necessary on the local machine; as the official F-Droid
build server has already accepted those licenses.

It is a bit complicated to setup, because it doesn't seem to be possible to
accept the licenses with the command line.  The recommended workaround is to
accept the licenses in the GUI of Android Studio, and upload the licenses
directory to the server afterwards. The best source for this procedure is:
https://developer.android.com/studio/intro/update.html#download-with-gradle

After I accepted the licenses in the GUI, I copied the license directory to the
server with `rsync -r android-studio/license b1.delta.chat:`.

After that didn't work out either, I decided to setup the fdroid server with
the debian packages instead.

### Trying with the debian packages

```
sudo apt install fdroidserver vagrant
cd fdroiddata
ulimit -n 2048
wget https://gitlab.com/fdroid/fdroidserver/raw/master/makebuildserver
python3 makebuildserver
fdroid build --server com.b44t.messenger:571
```

### Start the Build Process

Then I could start the build container to test it:

```
sudo docker run --rm -i --name fdrd -u $(id -u):$(id -g) -v $(pwd):/repo -v /home/missytake/android-ndk-r20b:/repo/ndk fdroid-built build -l -v com.b44t.messenger
```

As long as it's running, you can access its command line with 
`sudo docker exec -ti fdrd bash`.

