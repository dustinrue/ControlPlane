ControlPlane
============

Looking for new maintainer
--------------------------

This project is looking for a new maintainer. If this is you please contact me via twitter @dustinrue.

What is ControlPlane
--------------------

ControlPlane, a fork of MarcoPolo, brings context and location sensitive awareness to OS X.  With ControlPlane you can intelligently reconfigure your Mac or perform any number of actions based on input from a wide variety of evidence sources including but not limited to available WiFi networks, current location, connected monitors, connected and nearby bluetooth devices, currently running apps and other configurable sources.  You will find a full feature list at <http://www.controlplaneapp.com/feature-list>.

How ControlPlane Works
----------------------

Using fuzzy logic, ControlPlane decides where you are and/or what you are doing (called a Context) using rules that you configure to then carry out any number of configured actions.

An example of how to use ControlPlane may include disabling the screensaver password while at work but enabling it when away from work.  Another example would be to set your Adium status.

How to Get ControlPlane
-----------------------

You can download the most recent version of ControlPlane from [the ControlPlane website](http://www.controlplaneapp.com). Once installed you will be automatically notified of any new updates that become available.

Building ControlPlane from Source
---------------------------------

ControlPlane is free, open source software hosted at <https://github.com/dustinrue/ControlPlane>.  Before you can build ControlPlane you will need the following:

1. Xcode 4.4+.
2. A git client if you don't wish to use Xcode itself, the command line tools for Xcode include the Git command line client.
3. OS X version 10.8.

If you wish to build ControlPlane yourself you can do so by cloning the ControlPlane code to your computer using Xcode or your preferred git client.  Once cloned, open the project file in Xcode and edit the Action.h file to enable or disable the building of the iChat action.
