#!/bin/sh
osascript -e 'tell application "System Events" to set require password to wake of security preferences to true' || exit 1
