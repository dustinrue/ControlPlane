//
//	CPHelperTool.c
//	ControlPlane
//
//	Created by Dustin Rue on 3/9/11.
//	Copyright 2011. All rights reserved.
//

#import <netinet/in.h>
#import <sys/socket.h>
#import <stdio.h>
#import <unistd.h>
#import <CoreServices/CoreServices.h>

#import "AuthorizationLib/BetterAuthorizationSampleLib.h"
#import "CPHelperToolCommon.h"

extern const BASCommandSpec kCPHelperToolCommandSet[];
bool isLionOrHigher(void);


// Implements the GetVersionCommand. Returns the version number of the helper tool.
static OSStatus DoGetVersion(AuthorizationRef		auth,
							 const void *			userData,
							 CFDictionaryRef		request,
							 CFMutableDictionaryRef	response,
							 aslclient				asl,
							 aslmsg					aslMsg) {
	
	OSStatus retval = noErr;
	CFNumberRef value;
	static const unsigned int kCurrentVersion = kCPHelperToolVersionNumber;
	
	assert(auth != NULL);
	assert(request != NULL);
	assert(response != NULL);
	
	// Add to the response.
	value = CFNumberCreate(NULL, kCFNumberIntType, &kCurrentVersion);
	if (!value)
		retval = coreFoundationUnknownErr;
	else {
		CFDictionaryAddValue(response, CFSTR(kCPHelperToolGetVersionResponse), value);
		CFRelease(value);
	}
	
	return retval;
}

// enables time machine
static OSStatus DoEnableTM(AuthorizationRef			auth,
						   const void *				userData,
						   CFDictionaryRef			request,
						   CFMutableDictionaryRef	response,
						   aslclient				asl,
						   aslmsg					aslMsg) {
	
	assert(auth != NULL);
	assert(request != NULL);
	assert(response != NULL);
	
	char command[256];
	int retValue = 0;
	
	// if Lion or greater
	if (isLionOrHigher()) {
		sprintf(command,"/usr/bin/tmutil enable");
		retValue = system(command);
		
        // disabling local backups causes any stored local backups
        // to be deleted, this option is left here in case someone
        // actually wants to do that
        /*
		if (!retValue) {
			sprintf(command,"/usr/bin/tmutil enablelocal");
			retValue = system(command);
		}
        */
	} else {	// Snow leopard
		sprintf(command,"/usr/bin/defaults write /Library/Preferences/com.apple.TimeMachine.plist %s %s %s", "AutoBackup", "-boolean", "TRUE");
		retValue = system(command);
	}
	
	return retValue;
}

// disables time machine
static OSStatus DoDisableTM(AuthorizationRef		auth,
							const void *			userData,
							CFDictionaryRef			request,
							CFMutableDictionaryRef	response,
							aslclient				asl,
							aslmsg					aslMsg) {
	
	assert(auth != NULL);
	assert(request != NULL);
	assert(response != NULL);
	
	char command[256];
	int retValue = 0;
	
	// if Lion or greater
	if (isLionOrHigher()) {
		sprintf(command,"/usr/bin/tmutil disable");
		retValue = system(command);
		
        // disabling local backups causes any stored local backups
        // to be deleted, this option is left here in case someone
        // actually wants to do that
        /*
		if (!retValue) {
			sprintf(command,"/usr/bin/tmutil disablelocal");
			retValue = system(command);
		}
        */
	} else {	// Snow leopard
		sprintf(command,"/usr/bin/defaults write /Library/Preferences/com.apple.TimeMachine.plist %s %s %s", "AutoBackup", "-boolean", "FALSE");
		retValue = system(command);
	}
	
	return retValue;
}

// Start a Time Machine backup
static OSStatus DoStartBackupTM(AuthorizationRef		auth,
								const void *			userData,
								CFDictionaryRef			request,
								CFMutableDictionaryRef	response,
								aslclient				asl,
								aslmsg					aslMsg) {
	
	assert(auth != NULL);
	assert(request != NULL);
	assert(response != NULL);
	
	char command[256];
	int retValue = 0;
	
	// if Lion or greater
	if (isLionOrHigher()) {
		sprintf(command,"/usr/bin/tmutil startbackup");
		retValue = system(command);
	} else {	// Snow leopard
		sprintf(command, "/System/Library/CoreServices/backupd.bundle/Contents/Resources/backupd-helper &");
		retValue = system(command);
	}
	
	return retValue;
}

// Stop a Time Machine backup
static OSStatus DoStopBackupTM(AuthorizationRef			auth,
							   const void *				userData,
							   CFDictionaryRef			request,
							   CFMutableDictionaryRef	response,
							   aslclient				asl,
							   aslmsg					aslMsg) {
	
	assert(auth != NULL);
	assert(request != NULL);
	assert(response != NULL);
	
	char command[256];
	int retValue = 0;
	
	// if Lion or greater
	if (isLionOrHigher()) {
		sprintf(command,"/usr/bin/tmutil stopbackup");
		retValue = system(command);
	} else {	// Snow leopard
		sprintf(command, "/usr/bin/killall backupd-helper");
		retValue = system(command);
	}
	
	return retValue;
}

#pragma mark -
#pragma mark Tool Infrastructure

// the list defined here must match (same order) the list in CPHelperToolCommon.c
static const BASCommandProc kCPHelperToolCommandProcs[] = {
	DoGetVersion,
	DoEnableTM,
	DoDisableTM,
	DoStartBackupTM,
	DoStopBackupTM,
	NULL
};

int main(int argc, char **argv) {
	// Go directly into BetterAuthorizationSampleLib code.
	
	// IMPORTANT
	// BASHelperToolMain doesn't clean up after itself, so once it returns 
	// we must quit.
	
	return BASHelperToolMain(kCPHelperToolCommandSet, kCPHelperToolCommandProcs);
}

/**
 * Check if the OS is version 10.7 or higher
 */
bool isLionOrHigher(void) {
	SInt32 major = 0, minor = 0;

	// get system version
	Gestalt(gestaltSystemVersionMajor, &major);
	Gestalt(gestaltSystemVersionMinor, &minor);

	// test it
	return (major == 10 && minor >= 7) || major >= 11;
}
