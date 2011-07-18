#! /bin/sh

# make_disk_image.sh
# MarcoPolo
#
# Created by David Symonds on 17/02/07.

# Get version number
VERSION=`cat Info.plist | grep -A 1 'CFBundleShortVersionString' | \
	tail -1 | sed "s/[<>]/|/g" | cut -d\| -f3`

APPNAME=ControlPlane
IMG=$APPNAME-$VERSION.dmg
CONFIGURATION=Release
APP=build/$CONFIGURATION/$APPNAME.app
ICON=graphics/mp-volume.icns

xcodebuild -configuration "$CONFIGURATION" clean build
if [ ! -d "$APP" ]; then
	echo "Something failed in the build process!"
	exit 1
fi

# Create an initial disk image (32 megs)
if [ -f "$IMG" ]; then rm "$IMG"; fi
hdiutil create -size 32m -fs HFS+ -volname "$APPNAME-$VERSION" "$IMG" || exit 1

# Mount the disk image
hdiutil attach "$IMG" || exit 1

# Obtain device information
DEVS=$(hdiutil attach "$IMG" | grep HFS)
DEV=$(echo $DEVS | cut -d ' ' -f 1)
ROOT=$(echo $DEVS | cut -d ' ' -f 3)

# Copy files
cp -R $APP $ROOT
if [ -f "$ICON" ]; then
	cp $ICON $ROOT/.VolumeIcon.icns
	/Developer/Tools/SetFile -a C $ROOT
fi

# Unmount the disk image
hdiutil detach $DEV || exit 1

# Convert the disk image to read-only
TMP="tmp-${IMG}"
mv "$IMG" "$TMP"
hdiutil convert "$TMP" -format UDBZ -o "$IMG"
rm "$TMP"

ls -l "$IMG"
md5 "$IMG"

