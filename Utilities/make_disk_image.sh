#! /bin/sh

# make_disk_image.sh
# run this from the root project dir!
# ControlPlane
#
# Created by David Symonds on 17/02/07.
# Modified by Dustin Rue on 7/28/2011.

# Get version number
VERSION=`cat Info.plist | grep -A 1 'CFBundleShortVersionString' | \
	tail -1 | sed "s/[<>]/|/g" | cut -d\| -f3`

APPNAME=ControlPlane
IMG=$APPNAME-$VERSION.dmg
CONFIGURATION=Release
APP=build/$CONFIGURATION/$APPNAME.app
ICON=Resources/controlplane.icns

cd Utilities
./update-oui.sh
./update-usb-data.sh
cd ..

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


# sign the file for Sparkle
# run a helper script exposing location of private key for Sparkle updates
. sparkle_env.sh
ls -l "$IMG"
ruby "$SIGNING_SCRIPT" "$IMG" "$PRIVATE_KEY" 
