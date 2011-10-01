//
//  Action+HelperTool.m
//  ControlPlane
//
//  Created by David Jennes on 05/09/11.
//  Copyright 2011. All rights reserved.
//

#import "Action+HelperTool.h"
#import <libkern/OSAtomic.h>

@interface CAction (HelperTool_Private)

- (OSStatus) helperToolActualPerform: (NSString *) action withResponse: (CFDictionaryRef *) response andAuth: (AuthorizationRef) auth;
- (void) helperToolInit: (AuthorizationRef *) auth;
- (OSStatus) helperToolFix: (BASFailCode) failCode withAuth: (AuthorizationRef) auth;
- (void) helperToolAlert: (NSMutableDictionary *) parameters;

@end

@implementation CAction (HelperTool)

- (BOOL) helperToolPerformAction: (NSString *) action {
	static int32_t versionCheck = 0;
	
	CFDictionaryRef response = NULL;
	AuthorizationRef auth = NULL;
	OSStatus error = noErr;
	
	// initialize
	[self helperToolInit: &auth];
	
	if (!versionCheck) {
		// start version check
		OSAtomicIncrement32(&versionCheck);
		
		// get version of helper tool
		error = [self helperToolActualPerform: @kCPHelperToolGetVersionCommand withResponse: &response andAuth: auth];
		if (error) {
			OSAtomicDecrement32(&versionCheck);
			return NO;
		}
		
		// check version and update if needed
		NSNumber *version = [(NSDictionary *) response objectForKey: @kCPHelperToolGetVersionResponse];
		if ([version intValue] < kCPHelperToolVersionNumber)
			[self helperToolFix: kBASFailNeedsUpdate withAuth: auth];
		
		// finish version check
		OSAtomicIncrement32(&versionCheck);
	}
	
	//  wait until version check is done
	while (versionCheck < 2)
		[NSThread sleepForTimeInterval: 1];
	
	// perform actual action
	error = [self helperToolActualPerform: (NSString *) action withResponse: &response andAuth: auth];
	
	return (error ? NO : YES);
}

- (OSStatus) helperToolActualPerform: (NSString *) action
						withResponse: (CFDictionaryRef *) response
							 andAuth: (AuthorizationRef) auth {
	
	NSString *bundleID;
	NSDictionary *request;
	OSStatus error = 0;
	*response = NULL;
	
	// create request
	bundleID = [[NSBundle mainBundle] bundleIdentifier];
	ZAssert(bundleID != NULL, @"Unable to get bundle ID");
	request = [NSDictionary dictionaryWithObjectsAndKeys: action, @kBASCommandKey, nil];
	ZAssert(request != NULL, @"Unable to create request");
	
	// Execute it.
	error = BASExecuteRequestInHelperTool(auth,
										  kCPHelperToolCommandSet, 
										  (CFStringRef) bundleID, 
										  (CFDictionaryRef) request,
										  response);
	
	// If it failed, try to recover.
	if (error != noErr && error != userCanceledErr) {
		BASFailCode failCode = BASDiagnoseFailure(auth, (CFStringRef) bundleID);
		
		// try to fix
		error = [self helperToolFix: failCode withAuth: auth];
		
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
	ZAssert(err == noErr, @"Error creating authorization");
	ZAssert((err == noErr) == (*auth != NULL), @"Couldn't create authorization");
	
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

- (OSStatus) helperToolFix: (BASFailCode) failCode withAuth: (AuthorizationRef) auth {
	NSMutableDictionary *parameters = [[[NSMutableDictionary alloc] init] autorelease];
	NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
	OSStatus err = noErr;
	
	// At this point we tell the user that something has gone wrong and that we need 
	// to authorize in order to fix it.  Ideally we'd use failCode to describe the type of 
	// error to the user.
	
	[self performSelectorOnMainThread: @selector(helperToolAlert:) withObject: parameters waitUntilDone: YES];
	err = [[parameters objectForKey: @"result"] intValue];
	
	// Try to fix things.
	if (err == NSAlertDefaultReturn) {
		err = BASFixFailure(auth, (CFStringRef) bundleID, CFSTR("CPHelperInstallTool"), CFSTR("CPHelperTool"), failCode);
	} else
		err = userCanceledErr;
	
	return err;
}

- (void) helperToolAlert: (NSMutableDictionary *) parameters {
	NSInteger t = NSRunAlertPanel(NSLocalizedString(@"ControlPlane Helper Needed", @"Fix helper tool"),
								  NSLocalizedString(@"ControlPlane needs to install a helper app to enable and disable Time Machine", @"Fix helper tool"),
								  NSLocalizedString(@"Install", @"Fix helper tool"),
								  NSLocalizedString(@"Cancel", @"Fix helper tool"),
								  NULL);
	
	[parameters setObject: [NSNumber numberWithInteger: t] forKey: @"result"];
}

@end
