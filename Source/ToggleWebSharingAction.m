//
//  ToggleWebSharingAction.m
//  ControlPlane
//
//  Created by Dustin Rue on 3/27/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "ToggleWebSharingAction.h"
#import "CPHelperToolCommon.h"
#import "Action+HelperTool.h"

@implementation ToggleWebSharingAction

- (NSString *) description {
	if (turnOn)
		return NSLocalizedString(@"Enabling Web Sharing Service.", @"Act of turning on or enabling Web Sharing Service is being performed");
	else
		return NSLocalizedString(@"Disabling Web Sharing Service.", @"Act of turning off or disabling Web Sharing Service is being performed");
}

- (BOOL) execute: (NSString **) errorString {
    
    NSString *command = turnOn ? @kCPHelperToolEnableWebSharingCommand : @kCPHelperToolDisableWebSharingCommand;
	
	BOOL success = [self helperToolPerformAction: command];
    
	if (!success) {
		if (turnOn)
			*errorString = NSLocalizedString(@"Failed enabling Web Sharing Service.", @"Act of turning on or enabling Web Sharing Service failed");
		else
			*errorString = NSLocalizedString(@"Failed disabling Web Sharing Service.", @"Act of turning off or disabling Web Sharing Service failed");
	}
    
    
    
	return success;
}

+ (NSString *) helpText {
	return NSLocalizedString(@"The parameter for ToggleWebSharing actions is either \"1\" "
                             "or \"0\", depending on whether you want Web Sharing Service "
                             "turned on or off.", @"");
}

+ (NSString *) creationHelpText {
	return NSLocalizedString(@"Set Web Sharing Service", @"Will be followed by 'on' or 'off'");
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Toggle Web Sharing Service", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"Sharing", @"");
}


@end
