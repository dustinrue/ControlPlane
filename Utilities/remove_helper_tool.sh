#!/bin/bash


launchctl unload -F /Library/LaunchDaemons/com.dustinrue.ControlPlane.plist
rm /Library/LaunchDaemons/com.dustinrue.ControlPlane.plist
rm /Library/PrivilegedHelperTools//com.dustinrue.ControlPlane
