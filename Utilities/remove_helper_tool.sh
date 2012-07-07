#!/bin/bash

# a simple utility for removing the ControlPlane helper app
# *must* be run as root

launchctl unload -F /Library/LaunchDaemons/com.dustinrue.ControlPlane.plist
rm /Library/LaunchDaemons/com.dustinrue.ControlPlane.plist
rm /Library/PrivilegedHelperTools/com.dustinrue.ControlPlane

# newer version
launchctl unload -F /Library/LaunchDaemons/com.dustinrue.CPHelperTool.plist
rm /Library/LaunchDaemons/com.dustinrue.CPHelperTool.plist
rm /Library/PrivilegedHelperTools/com.dustinrue.CPHelperTool
