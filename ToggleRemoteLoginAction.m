//
//  ToggleRemoteLoginAction.m
//  ControlPlane
//
//  Created by Dustin Rue on 3/27/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "ToggleRemoteLoginAction.h"
#import "CPHelperToolCommon.h"
#import "Action+HelperTool.h"

@implementation ToggleRemoteLoginAction

- (NSString *) description {
	if (turnOn)
		return NSLocalizedString(@"Enabling Remote Login Service.", @"Act of turning on or enabling Remote Login Service is being performed");
	else
		return NSLocalizedString(@"Disabling Remote Login Service.", @"Act of turning off or disabling Remote Login Service is being performed");
}

- (BOOL) execute: (NSString **) errorString {
    
    NSString *command = turnOn ? @kCPHelperToolEnableRemoteLoginCommand : @kCPHelperToolDisableRemoteLoginCommand;
	
	BOOL success = [self helperToolPerformAction: command];
    
	if (!success) {
		if (turnOn)
			*errorString = NSLocalizedString(@"Failed enabling Remote Login Service.", @"Act of turning on or enabling Remote Login Service failed");
		else
			*errorString = NSLocalizedString(@"Failed disabling Remote Login Service.", @"Act of turning off or disabling Remote Login Service failed");
	}
    
    
    
	return success;
}

+ (NSString *) helpText {
	return NSLocalizedString(@"The parameter for ToggleRemoteLogin actions is either \"1\" "
                             "or \"0\", depending on whether you want Remote Login Service "
                             "turned on or off.", @"");
}

+ (NSString *) creationHelpText {
	return NSLocalizedString(@"Set Remote Login Service", @"Will be followed by 'on' or 'off'");
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Toggle Remote Login Service", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"Sharing", @"");
}

@end
