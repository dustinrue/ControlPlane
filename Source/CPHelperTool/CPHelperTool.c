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
#import <syslog.h>

#import "AuthorizationLib/BetterAuthorizationSampleLib.h"
#import "CPHelperToolCommon.h"

extern const BASCommandSpec kCPHelperToolCommandSet[];

static OSStatus DoInstallTool(
                              AuthorizationRef			auth,
                              const void *                userData,
                              CFDictionaryRef				request,
                              CFMutableDictionaryRef      response,
                              aslclient                   asl,
                              aslmsg                      aslMsg
                              )
// Implements the kInstallCommandLineTool command.  Returns the version number of
// the helper tool.
{
	OSStatus					retval = noErr;
	
	// Pre-conditions
	
	assert(auth != NULL);
    // userData may be NULL
	assert(request != NULL);
	assert(response != NULL);
    // asl may be NULL
    // aslMsg may be NULL
    
    // Retrieve the source path
    CFStringRef srcPath = (CFStringRef)CFDictionaryGetValue(request, CFSTR(kInstallCommandLineToolSrcPath));
    CFStringRef toolName = (CFStringRef)CFDictionaryGetValue(request, CFSTR(kInstallCommandLineToolName));
    
    // Check the code signature on the tool so that no-one else can use this to install stuff
	// We want to be sure that the cert is ours, and signed by apple
    
    // Note, I'm well aware that someone could hack the kSigningCertCommonName
    // static string in the data section of this binary. However, that is not a flaw
    // because the code signature of this binary would then be invalid and it would refuse
    // to be installed. Any potential hacker would have to replace all 3 binaries
    // (App, the install helper and the command line tool) to compromise it, at which
    // point it's not our app anymore anyway, and it would have to be signed by their own cert.
    
    bool success = true;
    
    char* ourFilename = 0;
    const char* pFilename = CFStringGetCStringPtr(srcPath, kCFStringEncodingMacRoman);
    
    if (!pFilename)
    {
        unsigned long len = CFStringGetLength(srcPath) + 20;
        ourFilename = malloc(len);
        if (!CFStringGetCString(srcPath, ourFilename, len, kCFStringEncodingMacRoman))
        {
            // freeing here will cause the compiler to complain, the if below should
            // catch this if it exists and free it then
            //free(ourFilename);
            retval = 3;
            success = false;
        }
        else
            pFilename = ourFilename;
    }
    
    if (pFilename)
    {
        // Base command minus cert name and file namem is 76 characters, 1 for NULL
        char* valCodeSignCmd = 0;
        // asprintf allocates & never overflows
        if (asprintf(&valCodeSignCmd, "codesign -v -R=\"certificate leaf[subject.CN] = \\\"%s\\\" and anchor apple generic\" \"%s\"", kSigningCertCommonName, pFilename) != -1)
        {
            if (system(valCodeSignCmd) == 0)
            {
                // Passed codesign validation
                // OK to copy now - overwrite if present
                OSStatus fsret = FSPathCopyObjectSync(pFilename, "/usr/local/bin", toolName, NULL, kFSFileOperationOverwrite);
                if (fsret != noErr)
                    success = false;
            }
            
            
            // Clean up
            free(valCodeSignCmd);
            
        }
        else
            success = false;
        
        
    }
    
    if (success)
        CFDictionaryAddValue(response, CFSTR(kInstallCommandLineToolResponse), kCFBooleanTrue);
    else
        CFDictionaryAddValue(response, CFSTR(kInstallCommandLineToolResponse), kCFBooleanFalse);
    
    if (ourFilename)
    {
        free(ourFilename);
        ourFilename = 0;
    }
    
    
	return retval;
}

// Implements the GetVersionCommand. Returns the version number of the helper tool.
static OSStatus DoGetVersion(AuthorizationRef			auth,
							 const void *				userData,
							 CFDictionaryRef			request,
							 CFMutableDictionaryRef		response,
							 aslclient					asl,
							 aslmsg						aslMsg) {
	
	OSStatus retval = noErr;
	CFNumberRef value;
	static const unsigned int kCurrentVersion = kCPHelperToolVersionNumber;
	
	assert(auth     != NULL);
	assert(request  != NULL);
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

#pragma mark Time Machine
// enables time machine
static OSStatus DoEnableTM (AuthorizationRef		auth,
							const void *			userData,
							CFDictionaryRef			request,
							CFMutableDictionaryRef	response,
							aslclient				asl,
							aslmsg					aslMsg) {
	
	assert(auth     != NULL);
	assert(request  != NULL);
	assert(response != NULL);
	
	char command[256];
	int retValue = 0;
	
	// get system version
	SInt32 major = 0, minor = 0;
	Gestalt(gestaltSystemVersionMajor, &major);
    Gestalt(gestaltSystemVersionMinor, &minor);
	
	// if Lion or greater
	if ((major == 10 && minor >= 7) || major >= 11) {
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
static OSStatus DoDisableTM (AuthorizationRef		auth,
							 const void *			userData,
							 CFDictionaryRef		request,
							 CFMutableDictionaryRef	response,
							 aslclient				asl,
							 aslmsg					aslMsg) {
	
	assert(auth     != NULL);
	assert(request  != NULL);
	assert(response != NULL);
	
	char command[256];
	int retValue = 0;
	
	// get system version
	SInt32 major = 0, minor = 0;
	Gestalt(gestaltSystemVersionMajor, &major);
    Gestalt(gestaltSystemVersionMinor, &minor);
	
	// if Lion or greater
	if ((major == 10 && minor >= 7) || major >= 11) {
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
static OSStatus DoStartBackupTM (AuthorizationRef		auth,
								 const void *			userData,
								 CFDictionaryRef		request,
								 CFMutableDictionaryRef	response,
								 aslclient				asl,
								 aslmsg					aslMsg) {
	
	assert(auth     != NULL);
	assert(request  != NULL);
	assert(response != NULL);
	
	char command[256];
	int retValue = 0;
	
	// get system version
	SInt32 major = 0, minor = 0;
	Gestalt(gestaltSystemVersionMajor, &major);
    Gestalt(gestaltSystemVersionMinor, &minor);
	
	// if Lion or greater
	if ((major == 10 && minor >= 7) || major >= 11) {
		sprintf(command,"/usr/bin/tmutil startbackup");
		retValue = system(command);
	} else {	// Snow leopard
		sprintf(command, "/System/Library/CoreServices/backupd.bundle/Contents/Resources/backupd-helper &");
		retValue = system(command);
	}
	
	return retValue;
}

// Stop a Time Machine backup
static OSStatus DoStopBackupTM (AuthorizationRef		auth,
								 const void *			userData,
								 CFDictionaryRef		request,
								 CFMutableDictionaryRef	response,
								 aslclient				asl,
								 aslmsg					aslMsg) {
	
	assert(auth     != NULL);
	assert(request  != NULL);
	assert(response != NULL);
	
	char command[256];
	int retValue = 0;
	
	// get system version
	SInt32 major = 0, minor = 0;
	Gestalt(gestaltSystemVersionMajor, &major);
    Gestalt(gestaltSystemVersionMinor, &minor);
	
	// if Lion or greater
	if ((major == 10 && minor >= 7) || major >= 11) {
		sprintf(command,"/usr/bin/tmutil stopbackup");
		retValue = system(command);
	} else {	// Snow leopard
		sprintf(command, "/usr/bin/killall backupd-helper");
		retValue = system(command);
	}
	
	return retValue;
}

#pragma mark Internet Sharing
// Enable Internet Sharing
static OSStatus DoEnableIS (AuthorizationRef		auth,
                            const void *			userData,
                            CFDictionaryRef         request,
                            CFMutableDictionaryRef	response,
                            aslclient				asl,
                            aslmsg					aslMsg) {
    assert(auth     != NULL);
	assert(request  != NULL);
	assert(response != NULL);
	
	char command[256];
	int retValue = 0;
    
    sprintf(command, "/bin/launchctl load -w /System/Library/LaunchDaemons/com.apple.InternetSharing.plist");
    retValue = system(command);
	
	
	return retValue;
}

// Disable Internet Sharing
static OSStatus DoDisableIS (AuthorizationRef		auth,
                            const void *			userData,
                            CFDictionaryRef         request,
                            CFMutableDictionaryRef	response,
                            aslclient				asl,
                            aslmsg					aslMsg) {
    assert(auth     != NULL);
	assert(request  != NULL);
	assert(response != NULL);
	
	char command[256];
	int retValue = 0;
    
    sprintf(command, "/bin/launchctl unload -w /System/Library/LaunchDaemons/com.apple.InternetSharing.plist");
    retValue = system(command);
	
	
	return retValue;
}

#pragma mark Firewall 
// Enable Firewall, this globally enables the firewall
static OSStatus DoEnableFirewall (AuthorizationRef          auth,
                                  const void *              userData,
                                  CFDictionaryRef           request,
                                  CFMutableDictionaryRef	response,
                                  aslclient                 asl,
                                  aslmsg					aslMsg) {
    assert(auth     != NULL);
	assert(request  != NULL);
	assert(response != NULL);
	
	char command[256];
	int retValue = 0;
    
    sprintf(command, "/usr/bin/defaults write /Library/Preferences/com.apple.alf globalstate -int 1");
    retValue = system(command);
	
	
	return retValue;
}

// Globally disable the firewall
static OSStatus DoDisableFirewall (AuthorizationRef         auth,
                                   const void *             userData,
                                   CFDictionaryRef          request,
                                   CFMutableDictionaryRef	response,
                                   aslclient				asl,
                                   aslmsg					aslMsg) {
    assert(auth     != NULL);
	assert(request  != NULL);
	assert(response != NULL);
	
	char command[256];
	int retValue = 0;
    
    sprintf(command, "/usr/bin/defaults write /Library/Preferences/com.apple.alf globalstate -int 0");
    retValue = system(command);
	
	
	return retValue;
}

#pragma mark -
#pragma mark Toggle Monitor Sleep

// Set Monitor Sleep Time routine
static OSStatus SetDisplaySleepTime (AuthorizationRef         auth,
                                     const void *             userData,
                                     CFDictionaryRef          request,
                                     CFMutableDictionaryRef   response,
                                     aslclient				  asl,
                                     aslmsg					  aslMsg) {
    
    assert(auth     != NULL);
	assert(request  != NULL);
	assert(response != NULL);
	
	char command[256];
	int retValue = 0;
    
    CFNumberRef parameter = (CFNumberRef) CFDictionaryGetValue(request, CFSTR("param"));

    int value = 0;
    
	if (!CFNumberGetValue(parameter, kCFNumberSInt32Type, &value))
		return BASErrnoToOSStatus(EINVAL);
    
    sprintf(command, "/usr/bin/pmset -a displaysleep %i", value);
    retValue = system(command);
	
	
	return retValue;
}

#pragma mark -
#pragma mark Printer Sharing Routines

static OSStatus DoEnablePrinterSharing (AuthorizationRef         auth,
                                        const void *             userData,
                                        CFDictionaryRef          request,
                                        CFMutableDictionaryRef   response,
                                        aslclient				  asl,
                                        aslmsg					  aslMsg) {
    assert(auth     != NULL);
	assert(request  != NULL);
	assert(response != NULL);
	
	char command[256];
	int retValue = 0;
    
    sprintf(command, "/usr/sbin/cupsctl --share-printers");
    retValue = system(command);
	
	
	return retValue;
}

static OSStatus DoDisablePrinterSharing (AuthorizationRef         auth,
                                         const void *             userData,
                                         CFDictionaryRef          request,
                                         CFMutableDictionaryRef   response,
                                         aslclient				  asl,
                                         aslmsg					  aslMsg) {
    assert(auth     != NULL);
	assert(request  != NULL);
	assert(response != NULL);
	
	char command[256];
	int retValue = 0;
    
    sprintf(command, "/usr/sbin/cupsctl --no-share-printers");
    retValue = system(command);
	
	
	return retValue;
}

static OSStatus DoEnableAFPFileSharing (AuthorizationRef         auth,
                                         const void *             userData,
                                         CFDictionaryRef          request,
                                         CFMutableDictionaryRef   response,
                                         aslclient				  asl,
                                         aslmsg					  aslMsg) {
    assert(auth     != NULL);
	assert(request  != NULL);
	assert(response != NULL);
	
	char command[256];
    char param[256];
	int retValue = 0;
    
    CFStringRef parameter = (CFStringRef) CFDictionaryGetValue(request, CFSTR("param"));
    
    if (!CFStringGetCString(parameter, param, sizeof(param) - 1, kCFStringEncodingUTF8))
        return BASErrnoToOSStatus(EINVAL);
    

    sprintf(command, "/bin/launchctl load -F /System/Library/LaunchDaemons/%s.plist", kCPHelperToolAFPServiceName);
    retValue = system(command);
	
	return retValue;
}

static OSStatus DoDisableAFPFileSharing (AuthorizationRef         auth,
                                      const void *             userData,
                                      CFDictionaryRef          request,
                                      CFMutableDictionaryRef   response,
                                      aslclient                asl,
                                      aslmsg                   aslMsg) {
    assert(auth     != NULL);
	assert(request  != NULL);
	assert(response != NULL);
	
	char command[256];
    char param[256];
	int retValue = 0;
    
    CFStringRef parameter = (CFStringRef) CFDictionaryGetValue(request, CFSTR("param"));
    
    if (!CFStringGetCString(parameter, param, sizeof(param) - 1, kCFStringEncodingUTF8))
        return BASErrnoToOSStatus(EINVAL);
    
    sprintf(command, "/bin/launchctl unload -F /System/Library/LaunchDaemons/%s.plist", kCPHelperToolAFPServiceName);
    retValue = system(command);

	return retValue;
}

static OSStatus DoEnableSMBFileSharing (AuthorizationRef         auth,
                                        const void *             userData,
                                        CFDictionaryRef          request,
                                        CFMutableDictionaryRef   response,
                                        aslclient				  asl,
                                        aslmsg					  aslMsg) {
    assert(auth     != NULL);
	assert(request  != NULL);
	assert(response != NULL);
	
	char sync_command[256];
    char enable_command[256];
	int retValue = 0;
    
    
    // get system version
    SInt32 major = 0, minor = 0;
    Gestalt(gestaltSystemVersionMajor, &major);
    Gestalt(gestaltSystemVersionMinor, &minor);
    
    
    if ((major == 10 && minor >= 9) || major >= 11) {
        sprintf(enable_command, "/bin/launchctl load -F /System/Library/LaunchDaemons/%s.plist", kCPHelperToolSMBDServiceName);
        sprintf(sync_command, "%s", kCPHelperToolSMBSyncToolFilePathMavericks);
    }
    else {
        sprintf(enable_command, "/usr/bin/defaults write %s 'EnabledServices' -array 'disk'", kCPHelperToolSMBPrefsFilePath);
        sprintf(sync_command, "%s", kCPHelperToolSMBSyncToolFilePath);
    }
    
    retValue = system(enable_command);
    
    if (!retValue) {
        retValue = system(sync_command);
    }
	
	return retValue;
}

static OSStatus DoDisableSMBFileSharing (AuthorizationRef         auth,
                                         const void *             userData,
                                         CFDictionaryRef          request,
                                         CFMutableDictionaryRef   response,
                                         aslclient                asl,
                                         aslmsg                   aslMsg) {
    assert(auth     != NULL);
	assert(request  != NULL);
	assert(response != NULL);
	
    char sync_command[256];
    char disable_command[256];
    int retValue = 0;
    
    
    // get system version
    SInt32 major = 0, minor = 0;
    Gestalt(gestaltSystemVersionMajor, &major);
    Gestalt(gestaltSystemVersionMinor, &minor);
    
    
    if ((major == 10 && minor >= 9) || major >= 11) {
        sprintf(disable_command, "/bin/launchctl unload -F /System/Library/LaunchDaemons/%s.plist", kCPHelperToolSMBDServiceName);
        sprintf(sync_command, "%s", kCPHelperToolSMBSyncToolFilePathMavericks);
    }
    else {
        sprintf(disable_command, "/usr/bin/defaults delete %s 'EnabledServices'", kCPHelperToolSMBPrefsFilePath);
        sprintf(sync_command, "%s", kCPHelperToolSMBSyncToolFilePath);
    }
    
    retValue = system(disable_command);
    
    if (!retValue) {
        retValue = system(sync_command);
    }
    
    return retValue;
}




static OSStatus DoEnableTFTP (AuthorizationRef         auth,
                              const void *             userData,
                              CFDictionaryRef          request,
                              CFMutableDictionaryRef   response,
                              aslclient				  asl,
                              aslmsg					  aslMsg) {
    assert(auth     != NULL);
	assert(request  != NULL);
	assert(response != NULL);
	
	char command[256];
	int retValue = 0;
    

    sprintf(command, "/bin/launchctl load -F /System/Library/LaunchDaemons/tftp.plist");
    retValue = system(command);
	
	return retValue;
}


static OSStatus DoDisableTFTP (AuthorizationRef         auth,
                               const void *             userData,
                               CFDictionaryRef          request,
                               CFMutableDictionaryRef   response,
                               aslclient				  asl,
                               aslmsg					  aslMsg) {
    assert(auth     != NULL);
	assert(request  != NULL);
	assert(response != NULL);
	
	char command[256];
	int retValue = 0;
    
    
    
    sprintf(command, "/bin/launchctl unload -F /System/Library/LaunchDaemons/tftp.plist");
    retValue = system(command);
	
	return retValue;
}


static OSStatus DoEnableFTP (AuthorizationRef         auth,
                                        const void *             userData,
                                        CFDictionaryRef          request,
                                        CFMutableDictionaryRef   response,
                                        aslclient				  asl,
                                        aslmsg					  aslMsg) {
    assert(auth     != NULL);
	assert(request  != NULL);
	assert(response != NULL);
	
	char command[256];

	int retValue = 0;
        
    sprintf(command, "/bin/launchctl load -F /System/Library/LaunchDaemons/ftp.plist");
    retValue = system(command);
	
	return retValue;
}

static OSStatus DoDisableFTP (AuthorizationRef         auth,
                                        const void *             userData,
                                        CFDictionaryRef          request,
                                        CFMutableDictionaryRef   response,
                                        aslclient				  asl,
                                        aslmsg					  aslMsg) {
    assert(auth     != NULL);
	assert(request  != NULL);
	assert(response != NULL);
	
	char command[256];

	int retValue = 0;
    
    sprintf(command, "/bin/launchctl unload -F /System/Library/LaunchDaemons/ftp.plist");
    retValue = system(command);
	
	return retValue;
}

static OSStatus DoEnableWebSharing (AuthorizationRef         auth,
                              const void *             userData,
                              CFDictionaryRef          request,
                              CFMutableDictionaryRef   response,
                              aslclient				  asl,
                              aslmsg					  aslMsg) {
    assert(auth     != NULL);
	assert(request  != NULL);
	assert(response != NULL);
	
	char command[256];
    
	int retValue = 0;
    
    sprintf(command, "/bin/launchctl load -F /System/Library/LaunchDaemons/org.apache.httpd.plist");
    retValue = system(command);
	
	return retValue;
}

static OSStatus DoDisableWebSharing (AuthorizationRef         auth,
                              const void *             userData,
                              CFDictionaryRef          request,
                              CFMutableDictionaryRef   response,
                              aslclient				  asl,
                              aslmsg					  aslMsg) {
    assert(auth     != NULL);
	assert(request  != NULL);
	assert(response != NULL);
	
	char command[256];
    
	int retValue = 0;
    
    sprintf(command, "/bin/launchctl unload -F /System/Library/LaunchDaemons/org.apache.httpd.plist");
    retValue = system(command);
	
	return retValue;
}

static OSStatus DoEnableRemoteLogin (AuthorizationRef         auth,
                              const void *             userData,
                              CFDictionaryRef          request,
                              CFMutableDictionaryRef   response,
                              aslclient				  asl,
                              aslmsg					  aslMsg) {
    assert(auth     != NULL);
	assert(request  != NULL);
	assert(response != NULL);
	
	char command[256];
    
	int retValue = 0;
    
    sprintf(command, "/bin/launchctl load -F /System/Library/LaunchDaemons/ssh.plist");
    retValue = system(command);
	
	return retValue;
}

static OSStatus DoDisableRemoteLogin (AuthorizationRef         auth,
                              const void *             userData,
                              CFDictionaryRef          request,
                              CFMutableDictionaryRef   response,
                              aslclient				  asl,
                              aslmsg					  aslMsg) {
    assert(auth     != NULL);
	assert(request  != NULL);
	assert(response != NULL);
	
	char command[256];
    
	int retValue = 0;
    
    sprintf(command, "/bin/launchctl unload -F /System/Library/LaunchDaemons/ssh.plist");
    retValue = system(command);
	
	return retValue;
}


#pragma mark -
#pragma mark Tool Infrastructure

// the list defined here must match (same order) the list in CPHelperToolCommon.c
static const BASCommandProc kCPHelperToolCommandProcs[] = {
    DoInstallTool,
	DoGetVersion,
	DoEnableTM,
	DoDisableTM,
	DoStartBackupTM,
	DoStopBackupTM,
    DoEnableIS,
    DoDisableIS,
    DoEnableFirewall,
    DoDisableFirewall,
    SetDisplaySleepTime,
    DoEnablePrinterSharing,
    DoDisablePrinterSharing,
    DoEnableAFPFileSharing,
    DoDisableAFPFileSharing,
    DoEnableSMBFileSharing,
    DoDisableSMBFileSharing,
    DoEnableTFTP,
    DoDisableTFTP,
    DoEnableFTP,
    DoDisableFTP,
    DoEnableWebSharing,
    DoDisableWebSharing,
    DoEnableRemoteLogin,
    DoDisableRemoteLogin,
	NULL
};

int main(int argc, char **argv) {
	// Go directly into BetterAuthorizationSampleLib code.
	
	// IMPORTANT
	// BASHelperToolMain doesn't clean up after itself, so once it returns 
	// we must quit.
	
	return BASHelperToolMain(kCPHelperToolCommandSet, kCPHelperToolCommandProcs);
}
