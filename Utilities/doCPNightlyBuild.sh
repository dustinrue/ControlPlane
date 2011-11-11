#!/bin/bash

# this script is called by the launchd file
# to use this, chances are pretty good you need
# to customize it to your environment

echo "Doing nightly build of ControlPlane"
cd /Users/dustin/Development/ControlPlane-Nightly
git pull origin master
./Utilities/make_nightly_image.sh 2>&1 >> build-log 
mv ControlPlane-NIGHTLY*dmg ~/Dropbox/Public/ControlPlane
