//
//	CPHelperTool.c
//	ControlPlane
//
//	Created by Dustin Rue on 9/3/11.
//	Copyright 2011. All rights reserved.
//

#include <netinet/in.h>
#include <sys/socket.h>
#include <stdio.h>
#include <unistd.h>
#include <CoreServices/CoreServices.h>

#include "AuthorizationLib/BetterAuthorizationSampleLib.h"
#include "CPHelperToolCommon.h"


static OSStatus DoEnableTMSL (AuthorizationRef			auth,
							  const void *				userData,
							  CFDictionaryRef			request,
							  CFMutableDictionaryRef	response,
							  aslclient					asl,
							  aslmsg					aslMsg) {
	
	assert(auth != NULL);
	assert(request != NULL);
	assert(response != NULL);

	char command[256];

	sprintf(command,"defaults write /Library/Preferences/com.apple.TimeMachine.plist %s %s %s", "AutoBackup", "-boolean", "TRUE");

	return system(command);
}

static OSStatus DoDisableTMSL (AuthorizationRef			auth,
							   const void *				userData,
							   CFDictionaryRef			request,
							   CFMutableDictionaryRef	response,
							   aslclient				asl,
							   aslmsg					aslMsg) {
	
	assert(auth != NULL);
	assert(request != NULL);
	assert(response != NULL);

	char command[256];

	sprintf(command,"defaults write /Library/Preferences/com.apple.TimeMachine.plist %s %s %s", "AutoBackup", "-boolean", "FALSE");

	return system(command);
}


// enables time machine on Lion, including MobileBackups
static OSStatus DoEnableTMLion (AuthorizationRef		auth,
								const void *			userData,
								CFDictionaryRef			request,
								CFMutableDictionaryRef	response,
								aslclient				asl,
								aslmsg					aslMsg) {
	
	int commandFailed = 0;

	assert(auth != NULL);
	assert(request != NULL);
	assert(response != NULL);

	char command[256];

	sprintf(command,"/usr/bin/tmutil enable");
	commandFailed = system(command);

	if (!commandFailed) {
		sprintf(command,"/usr/bin/tmutil enablelocal");
		return system(command);
	}

	return 0;
}


// disables time machine on Lion, including MobileBackups
static OSStatus DoDisableTMLion (AuthorizationRef		auth,
								 const void *			userData,
								 CFDictionaryRef		request,
								 CFMutableDictionaryRef	response,
								 aslclient				asl,
								 aslmsg					aslMsg) {
	
	int commandFailed = 0;

	assert(auth != NULL);
	assert(request != NULL);
	assert(response != NULL);

	char command[256];

	sprintf(command,"/usr/bin/tmutil disable");
	commandFailed = system(command);

	if (!commandFailed) {
		sprintf(command,"/usr/bin/tmutil disablelocal");
		return system(command);
	}

	return 0;
}

// Stop a Time Machine backup
static OSStatus DoStopBackupTM (AuthorizationRef		auth,
								const void *			userData,
								CFDictionaryRef			request,
								CFMutableDictionaryRef	response,
								aslclient				asl,
								aslmsg					aslMsg) {
	
	assert(auth != NULL);
	assert(request != NULL);
	assert(response != NULL);
	
	char command[256];
	
	sprintf(command, "/usr/bin/killall backupd-helper");
	
	return system(command);
}

// the list defined here must match (same order) the list in CPHelperToolCommon.c
static const BASCommandProc kCPHelperToolCommandProcs[] = {
	DoEnableTMSL,
	DoDisableTMSL,
	DoEnableTMLion,
	DoDisableTMLion,
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