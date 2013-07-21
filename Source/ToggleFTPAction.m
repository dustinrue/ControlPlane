//
//  ToggleFTPAction.m
//  ControlPlane
//
//  Created by Dustin Rue on 3/26/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "ToggleFTPAction.h"
#import "CPHelperToolCommon.h"
#import "Action+HelperTool.h"

@implementation ToggleFTPAction

- (NSString *) description {
	if (turnOn)
		return NSLocalizedString(@"Enabling FTP Service.", @"Act of turning on or enabling FTP Service is being performed");
	else
		return NSLocalizedString(@"Disabling FTP Service.", @"Act of turning off or disabling FTP Service is being performed");
}

- (BOOL) execute: (NSString **) errorString {
    
    NSString *command = turnOn ? @kCPHelperToolEnableFTPCommand : @kCPHelperToolDisableFTPCommand;
	
	BOOL success = [self helperToolPerformAction: command];
    
    
	if (!success) {
		if (turnOn)
			*errorString = NSLocalizedString(@"Failed enabling FTP Service.", @"Act of turning on or enabling FTP Service failed");
		else
			*errorString = NSLocalizedString(@"Failed disabling FTP Service.", @"Act of turning off or disabling FTP Service failed");
	}
    
	return success;
}

+ (NSString *) helpText {
	return NSLocalizedString(@"The parameter for ToggleFTP actions is either \"1\" "
                             "or \"0\", depending on whether you want FTP Service "
                             "turned on or off.", @"");
}

+ (NSString *) creationHelpText {
	return NSLocalizedString(@"Set FTP Service", @"Will be followed by 'on' or 'off'");
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Toggle FTP Service", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"Sharing", @"");
}

@end
