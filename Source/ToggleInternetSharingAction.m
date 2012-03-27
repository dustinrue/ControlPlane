//
//  ToggleInternetSharingAction.m
//  ControlPlane
//
//  Created by Dustin Rue on 10/19/11.
//  Copyright (c) 2011. All rights reserved.
//

#import "ToggleInternetSharingAction.h"
#import "Action+HelperTool.h"

@implementation ToggleInternetSharingAction


- (NSString *) description {
	if (turnOn)
		return NSLocalizedString(@"Enabling Internet Sharing.", @"Act of turning on or enabling internet sharing is being performed");
	else
		return NSLocalizedString(@"Disabling Internet Sharing.", @"Act of turning off or disabling internet sharing is being performed");
}

- (BOOL) execute: (NSString **) errorString {
	NSString *command = turnOn ? @kCPHelperToolEnableISCommand : @kCPHelperToolDisableISCommand;
	
	BOOL result = [self helperToolPerformAction: command];
	
	if (!result) {
		if (turnOn)
			*errorString = NSLocalizedString(@"Failed enabling internet sharing.", @"Act of turning on or enabling internet sharing failed");
		else
			*errorString = NSLocalizedString(@"Failed disabling internet sharing.", @"Act of turning off or disabling internet sharing failed");
	}
	
	return result;
}

+ (NSString *) helpText {
	return NSLocalizedString(@"The parameter for the InternetSharing action is either \"1\" "
                             "or \"0\", depending on whether you want to enable or disable internet sharing."
                             "", @"");
}

+ (NSString *) creationHelpText {
	return NSLocalizedString(@"Set Internet Sharing", @"Will be followed by 'on' or 'off'");
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Toggle Internet Sharing", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"Sharing", @"");
}

@end
