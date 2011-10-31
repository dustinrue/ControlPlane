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

#import "AuthorizationLib/BetterAuthorizationLib.h"
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

#pragma mark - Firewall

// Globally enable or disable the Firewall
static OSStatus DoSetEnabledFW(AuthorizationRef			auth,
							   const void *				userData,
							   CFDictionaryRef			request,
							   CFMutableDictionaryRef	response,
							   aslclient				asl,
							   aslmsg					aslMsg) {
	
	OSStatus retValue = noErr;
	char command[256];
	
	assert(auth != NULL);
	assert(request != NULL);
	assert(response != NULL);
	
	// check request parameter
	CFBooleanRef parameter = (CFBooleanRef) CFDictionaryGetValue(request, CFSTR("param"));
	if (parameter == NULL || CFGetTypeID(parameter) != CFBooleanGetTypeID())
		return BASErrnoToOSStatus(EINVAL);
	
	// if Lion or greater
	if (isLionOrHigher())
		sprintf(command, "/usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate %s",
				parameter == kCFBooleanTrue ? "on" : "off");
	// Snow Leopard
	else
		sprintf(command, "/usr/bin/defaults write /Library/Preferences/com.apple.alf globalstate -int %d",
				parameter == kCFBooleanTrue);
	
	retValue = system(command);
	return retValue;
}

#pragma mark - Internet Sharing

// Enable or disable Internet Sharing
static OSStatus DoSetEnabledIS(AuthorizationRef			auth,
							   const void *				userData,
							   CFDictionaryRef			request,
							   CFMutableDictionaryRef	response,
							   aslclient				asl,
							   aslmsg					aslMsg) {
	
	OSStatus retValue = noErr;
	char command[256];
	
	assert(auth != NULL);
	assert(request != NULL);
	assert(response != NULL);
	
	// check request parameter
	CFBooleanRef parameter = (CFBooleanRef) CFDictionaryGetValue(request, CFSTR("param"));
	if (parameter == NULL || CFGetTypeID(parameter) != CFBooleanGetTypeID())
		return BASErrnoToOSStatus(EINVAL);
	
	sprintf(command, "/bin/launchctl %s -w /System/Library/LaunchDaemons/com.apple.InternetSharing.plist",
			parameter == kCFBooleanTrue ? "load" : "unload");
	retValue = system(command);
	
	return retValue;
}

#pragma mark - Time Machine

// Enables or disables time machine
static OSStatus DoSetEnabledTM(AuthorizationRef			auth,
							   const void *				userData,
							   CFDictionaryRef			request,
							   CFMutableDictionaryRef	response,
							   aslclient				asl,
							   aslmsg					aslMsg) {
	
	OSStatus retValue = noErr;
	char command[256];
	
	assert(auth != NULL);
	assert(request != NULL);
	assert(response != NULL);
	
	// check request parameter
	CFBooleanRef parameter = (CFBooleanRef) CFDictionaryGetValue(request, CFSTR("param"));
	if (parameter == NULL || CFGetTypeID(parameter) != CFBooleanGetTypeID())
		return BASErrnoToOSStatus(EINVAL);
	
	// if Lion or greater
	if (isLionOrHigher()) {
		sprintf(command, "/usr/bin/tmutil %s", parameter == kCFBooleanTrue ? "enable" : "disable");
		//retValue = system(command);
		
		// disabling local backups causes any stored local backups
		// to be deleted, this option is left here in case someone
		// actually wants to do that
		/*
		if (!retValue) {
			sprintf(command, "/usr/bin/tmutil %s", parameter == kCFBooleanTrue ? "enablelocal" : "disablelocal");
			retValue = system(command);
		}*/
		
	// Snow leopard
	} else
		sprintf(command, "/usr/bin/defaults write /Library/Preferences/com.apple.TimeMachine.plist AutoBackup -boolean %s",
				parameter == kCFBooleanTrue ? "TRUE" : "FALSE");
	
	retValue = system(command);
	return retValue;
}

// Start or stop a Time Machine backup
static OSStatus DoControlBackupTM(AuthorizationRef			auth,
								  const void *				userData,
								  CFDictionaryRef			request,
								  CFMutableDictionaryRef	response,
								  aslclient					asl,
								  aslmsg					aslMsg) {
	
	OSStatus retValue = noErr;
	char command[256];
	
	assert(auth != NULL);
	assert(request != NULL);
	assert(response != NULL);
	
	// check request parameter
	CFBooleanRef parameter = (CFBooleanRef) CFDictionaryGetValue(request, CFSTR("param"));
	if (parameter == NULL || CFGetTypeID(parameter) != CFBooleanGetTypeID())
		return BASErrnoToOSStatus(EINVAL);
	
	// if Lion or greater
	if (isLionOrHigher())
		sprintf(command, "/usr/bin/tmutil %s", parameter == kCFBooleanTrue ? "startbackup" : "stopbackup");
		
	// Snow leopard
	else {
		if (parameter == kCFBooleanTrue)
			sprintf(command, "/System/Library/CoreServices/backupd.bundle/Contents/Resources/backupd-helper &");
		else
			sprintf(command, "/usr/bin/killall backupd-helper");
	}
	
	retValue = system(command);
	return retValue;
}

#pragma mark - Tool Infrastructure

// the list defined here must match (same order) the list in CPHelperToolCommon.c
static const BASCommandProc kCPHelperToolCommandProcs[] = {
	DoGetVersion,
	DoSetEnabledFW,
	DoSetEnabledIS,
	DoSetEnabledTM,
	DoControlBackupTM,
	NULL
};

int main(int argc, char **argv) {
	// Go directly into BetterAuthorizationLib code.
	
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
