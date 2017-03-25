//
//  Action+HelperTool.m
//  ControlPlane
//
//  Created by David Jennes on 05/09/11.
//  Copyright 2011. All rights reserved.
//
// Reworked by Dustin Rue to support SMJobBless, thanks to Steve Streeting for making this easier
// to figure out and doing most of the leg work
// -- http://www.stevestreeting.com/2012/03/05/follow-up-os-x-privilege-escalation-without-using-deprecated-methods/


#import "Action+HelperTool.h"
#import <libkern/OSAtomic.h>
#import <ServiceManagement/ServiceManagement.h>
#import <Security/Security.h>
#import <Security/Authorization.h>
#import <Security/Security.h>
#import <Security/SecCertificate.h>
#import <Security/SecCode.h>
#import <Security/SecStaticCode.h>
#import <Security/SecCodeHost.h>
#import <Security/SecRequirement.h>

@interface Action (HelperTool_Private)

- (OSStatus) helperToolActualPerform: (NSString *) action
                                    withParameter: (id) parameter
                                         response: (CFDictionaryRef *) response
                                             auth: (AuthorizationRef) auth;
- (void) helperToolInit: (AuthorizationRef *) auth;
- (OSStatus) helperToolFix: (BASFailCode) failCode withAuth: (AuthorizationRef) auth;
- (void) helperToolAlert: (NSMutableDictionary *) parameters;

BOOL installHelperToolUsingSMJobBless(void);
BOOL blessHelperWithLabel(NSString* label, NSError** error);

@end

@implementation Action (HelperTool)

- (BOOL) helperToolPerformAction: (NSString *) action {
    return [self helperToolPerformAction:action withParameter:nil];
}

- (BOOL) helperToolPerformAction: (NSString *) action withParameter: (id) parameter {
	static int32_t versionCheck = 0;
	
	helperToolResponse = NULL;
	AuthorizationRef auth = NULL;
	OSStatus error = noErr;
	
	// initialize
	[self helperToolInit: &auth];
	
	if (!versionCheck) {
		// start version check
		OSAtomicIncrement32(&versionCheck);
		
		// get version of helper tool
		error = [self helperToolActualPerform: @kCPHelperToolGetVersionCommand withParameter:nil response: &helperToolResponse auth: auth];
		if (error) {
			OSAtomicDecrement32(&versionCheck);
			return NO;
		}
		
		// check version and update if needed
		NSNumber *version = [(NSDictionary *) helperToolResponse objectForKey: @kCPHelperToolGetVersionResponse];
		if ([version intValue] < kCPHelperToolVersionNumber)
            installHelperToolUsingSMJobBless();
			//[self helperToolFix: kBASFailNeedsUpdate withAuth: auth];
		
		// finish version check
		OSAtomicIncrement32(&versionCheck);
	}
	
	//  wait until version check is done
	while (versionCheck < 2)
		[NSThread sleepForTimeInterval: 1];
	
	// perform actual action
	error = [self helperToolActualPerform: (NSString *) action withParameter: parameter response: &helperToolResponse auth: auth];
	
	return (error ? NO : YES);
}

- (OSStatus) helperToolActualPerform: (NSString *) action
                       withParameter: (id) parameter
                            response: (CFDictionaryRef *) response
                                auth: (AuthorizationRef) auth {
	
	NSString *bundleID;
	NSDictionary *request;
	OSStatus error = 0;
	*response = NULL;
	
	// create request
    // get the bundleID from the Info dictionary, it is the SMPrivilegedExcutable entry
    // For ControlPlane there is just helper so this is essentially hard coded to returning the first
    // entry in the dictionary.  If more were added then this would need to be able to specify the proper
    // helper tool to use based on the command to be run.
	bundleID = [[[[[NSBundle mainBundle] infoDictionary] objectForKey:@"SMPrivilegedExecutables"] allKeys] objectAtIndex:0];
	assert(bundleID != NULL);
	if (parameter)
		request = [NSDictionary dictionaryWithObjectsAndKeys: action, @kBASCommandKey, parameter, @"param", nil];
	else
		request = [NSDictionary dictionaryWithObjectsAndKeys: action, @kBASCommandKey, nil];
	assert(request != NULL);
	
	// Execute it.
	error = BASExecuteRequestInHelperTool(auth,
										  kCPHelperToolCommandSet, 
										  (CFStringRef) bundleID,
										  (CFDictionaryRef) request,
										  response);
	
	// If it failed, try to recover.
	if (error != noErr && error != userCanceledErr) {
        // for now we don't care about the failCode, we just try to install it again
		//BASFailCode failCode = BASDiagnoseFailure(auth, (CFStringRef) bundleID);
        BASDiagnoseFailure(auth, (CFStringRef) bundleID);
		
		// try to fix
		//error = [self installHelperToolUsingSMJobBless: failCode withAuth: auth];
        error = installHelperToolUsingSMJobBless();
		
		// If the fix went OK, retry the request.
		if (error == noErr)
			error = BASExecuteRequestInHelperTool(auth,
												  kCPHelperToolCommandSet,
												  (CFStringRef) bundleID,
												  (CFDictionaryRef) request,
												  response);
	}
	
	// If all of the above went OK, it means that the IPC to the helper tool worked.  We 
	// now have to check the response dictionary to see if the command's execution within 
	// the helper tool was successful.
	
	if (error == noErr)
		error = BASGetErrorFromResponse(*response);
	
	return error;
}

- (void) helperToolInit: (AuthorizationRef *) auth {
	OSStatus err = 0;
	
	// Create the AuthorizationRef that we'll use through this application.  We ignore 
	// any error from this.  A failure from AuthorizationCreate is very unusual, and if it 
	// happens there's no way to recover; Authorization Services just won't work.
	
	err = AuthorizationCreate(NULL, NULL, kAuthorizationFlagDefaults, auth);
	assert(err == noErr);
	assert((err == noErr) == (*auth != NULL));
	
	// For each of our commands, check to see if a right specification exists and, if not,
	// create it.
	//
	// The last parameter is the name of a ".strings" file that contains the localised prompts 
	// for any custom rights that we use.
	
	BASSetDefaultRules(*auth, 
					   kCPHelperToolCommandSet, 
					   CFBundleGetIdentifier(CFBundleGetMainBundle()), 
					   CFSTR("CPHelperToolAuthorizationPrompts"));
}


BOOL installHelperToolUsingSMJobBless(void) {
    // This uses SMJobBless to install a tool in /Library/PrivilegedHelperTools which is
    // run by launchd instead of us, with elevated privileges. This can then be used to do
    // things like install utilities in /usr/local/bin
    
    // We do this rather than AuthorizationExecuteWithPrivileges because that's deprecated in 10.7
    // The SMJobBless approach is more secure because both ends are validated via code signing
    // which is enforced by launchd - ie only tools signed with the right cert can be installed, and
    // only apps signed with the right cert can install it.
    
    // Although the launchd approach is primarily associated with daemons, it can be used for one-off
    // tools too. We effectively invoke the privileged helper by talking to it over a private Unix socket
    // (since we can't launch it directly). We still need to be careful about that invocation because
    // the SMJobBless structure doesn't validate that the caller at runtime is the right application.
    
    NSError* error = nil;
    NSDictionary*	installedHelperJobData 	= (NSDictionary*)SMJobCopyDictionary(kSMDomainSystemLaunchd, (CFStringRef)kPRIVILEGED_HELPER_LABEL);
    BOOL needToInstall = YES;
    
    if (installedHelperJobData) {
        NSURL* installedPathURL = [NSURL fileURLWithPath:[[installedHelperJobData objectForKey:@"ProgramArguments"] objectAtIndex:0]];
        [installedHelperJobData release];
        
        NSDictionary* installedInfoPlist = (NSDictionary*)CFBundleCopyInfoDictionaryForURL( (CFURLRef)installedPathURL );
        NSInteger installedVersion = [[installedInfoPlist objectForKey:@"CFBundleVersion"] integerValue];
        [installedInfoPlist release];
        
        NSLog( @"installedVersion: %ld", (long)installedVersion );
        
        NSBundle* appBundle	= [NSBundle mainBundle];
        NSURL* appBundleURL	= [appBundle bundleURL];
        
        NSURL* currentHelperToolURL	= [appBundleURL URLByAppendingPathComponent:[NSString stringWithFormat:@"Contents/Library/LaunchServices/%@", kPRIVILEGED_HELPER_LABEL]];
        NSLog( @"currentHelperToolURL: %@", currentHelperToolURL );
        
        NSDictionary* currentInfoPlist = (NSDictionary*)CFBundleCopyInfoDictionaryForURL( (CFURLRef)currentHelperToolURL );
        NSInteger currentVersion  = [[currentInfoPlist objectForKey:@"CFBundleVersion"] integerValue];
        [currentInfoPlist release];
        
        NSLog( @"currentVersion: %ld", (long)currentVersion );
        
      	if ( currentVersion == installedVersion )
        {
            SecRequirementRef requirement;
            OSStatus stErr;
            
            stErr = SecRequirementCreateWithString((CFStringRef)[NSString stringWithFormat:@"identifier %@ and certificate leaf[subject.CN] = \"%@\"", kPRIVILEGED_HELPER_LABEL, @kSigningCertCommonName], kSecCSDefaultFlags, &requirement );
            
            if ( stErr == noErr )
            {
                SecStaticCodeRef staticCodeRef;
                
                stErr = SecStaticCodeCreateWithPath( (CFURLRef)installedPathURL, kSecCSDefaultFlags, &staticCodeRef );
                
                if ( stErr == noErr )
                {
                    stErr = SecStaticCodeCheckValidity( staticCodeRef, kSecCSDefaultFlags, requirement );
                    
                    if (stErr != noErr) {
                        NSLog(@"unknown error in SecStaticCodeCheckValidity");
                    }
                    
                    needToInstall = NO;
                }
            }
        }
	}
    
    
    if (needToInstall)
    {
        NSLog(@"blessing %@", kPRIVILEGED_HELPER_LABEL);
        if (!blessHelperWithLabel(kPRIVILEGED_HELPER_LABEL, &error))
        {
            NSLog(@"Failed to install privileged helper: %@", [error description]);
            dispatch_async(dispatch_get_main_queue(), ^{
                NSRunAlertPanel(@"Error",
                                @"Failed to install privileged helper: %@",
                                @"OK", nil, nil, [error description]);
            });
            
            return NO;
        }
        else
            NSLog(@"Privileged helper installed.");
    }
    else
		NSLog(@"Privileged helper already available, not installing.");
    
    return YES;
    
}

// Code below adapted from the SMJobBless example
BOOL blessHelperWithLabel(NSString* label, NSError** error) {
	BOOL result = NO;
    
	AuthorizationItem authItem		= { kSMRightBlessPrivilegedHelper, 0, NULL, 0 };
	AuthorizationRights authRights	= { 1, &authItem };
	AuthorizationFlags flags		=	kAuthorizationFlagDefaults				|
    kAuthorizationFlagInteractionAllowed	|
    kAuthorizationFlagPreAuthorize			|
    kAuthorizationFlagExtendRights;
    
	AuthorizationRef authRef = NULL;
	
	/* Obtain the right to install privileged helper tools (kSMRightBlessPrivilegedHelper). */
	OSStatus status = AuthorizationCreate(&authRights, kAuthorizationEmptyEnvironment, flags, &authRef);
	if (status != errAuthorizationSuccess)
    {
		NSLog(@"Failed to create AuthorizationRef, return code %ld", (long)status);
	} else
    {
		/* This does all the work of verifying the helper tool against the application
		 * and vice-versa. Once verification has passed, the embedded launchd.plist
		 * is extracted and placed in /Library/LaunchDaemons and then loaded. The
		 * executable is placed in /Library/PrivilegedHelperTools.
		 */
		result = SMJobBless(kSMDomainSystemLaunchd, (CFStringRef)label, authRef, (CFErrorRef *)error);
	}
    
    AuthorizationFree(authRef, kAuthorizationFlagDefaults);
    
	
	return result;
}

- (void) helperToolAlert: (NSMutableDictionary *) parameters {
	NSInteger t = NSRunAlertPanel(NSLocalizedString(@"ControlPlane Helper Needed", @"Fix helper tool"),
								  NSLocalizedString(@"ControlPlane needs to install a helper app to enable and disable some items", @"Fix helper tool"),
								  NSLocalizedString(@"Install", @"Fix helper tool"),
								  NSLocalizedString(@"Cancel", @"Fix helper tool"),
								  NULL);
	
	[parameters setObject: [NSNumber numberWithInteger: t] forKey: @"result"];
}

@end
