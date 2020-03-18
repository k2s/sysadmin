#!/bin/sh

cd /home/fdroid/deltachat-android

git pull origin master > ../last-pull.txt
pullresult=`diff ../last-pull.txt ../uptodate.txt`

if [ -z "$pullresult" ]
then
	echo "No changes on master, exiting nightly build script."
	exit 0
fi

# let the script fail if one build step fails
set -e

echo "Building deltachat-android nightly on commit $(git rev-parse HEAD)"

# Build instructions from https://github.com/deltachat/deltachat-android/#build-using-dockerfile
# Remove the build directory
docker run -it -v $(pwd):/home/app -w /home/app deltachat-android rm -rf build/
# Build the build container with docker
docker build . -t deltachat-android --no-cache
# Prepare the build environment
docker run -it -v $(pwd):/home/app -w /home/app deltachat-android ./ndk-make.sh
# Build the apk
docker run -it -v $(pwd):/home/app -w /home/app deltachat-android ./gradlew assembleDebug

echo "Build output at /home/fdroid/deltachat-android/build/outputs/apk/gplay/debug/"

date=$(date '+%Y-%m-%d')

# Upload to download.delta.chat
rsync -vhr /home/fdroid/deltachat-android/build/outputs/apk/gplay/debug/*.apk android-nightly@download.delta.chat:/var/www/html/download/android/nightly/$date/

echo "Build uploaded to https://download.delta.chat/android/nightly/$date/"

