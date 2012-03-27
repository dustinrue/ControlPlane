//
//  ToggleTFTPAction.m
//  ControlPlane
//
//  Created by Dustin Rue on 3/26/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "ToggleTFTPAction.h"
#import "CPHelperToolCommon.h"
#import "Action+HelperTool.h"

@implementation ToggleTFTPAction

- (NSString *) description {
	if (turnOn)
		return NSLocalizedString(@"Enabling TFTP Service.", @"Act of turning on or enabling TFTP Service is being performed");
	else
		return NSLocalizedString(@"Disabling TFTP Service.", @"Act of turning off or disabling TFTP Service is being performed");
}

- (BOOL) execute: (NSString **) errorString {
    
    NSString *command = turnOn ? @kCPHelperToolEnableTFTPCommand : @kCPHelperToolDisableTFTPCommand;
	
	BOOL success = [self helperToolPerformAction: command];
    
	if (!success) {
		if (turnOn)
			*errorString = NSLocalizedString(@"Failed enabling TFTP Service.", @"Act of turning on or enabling TFTP Service failed");
		else
			*errorString = NSLocalizedString(@"Failed disabling TFTP Service.", @"Act of turning off or disabling TFTP Service failed");
	}
    

    
	return success;
}

+ (NSString *) helpText {
	return NSLocalizedString(@"The parameter for ToggleTFTP actions is either \"1\" "
                             "or \"0\", depending on whether you want TFTP Service "
                             "turned on or off.", @"");
}

+ (NSString *) creationHelpText {
	return NSLocalizedString(@"Set TFTP Service", @"Will be followed by 'on' or 'off'");
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Toggle TFTP Service", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"Sharing", @"");
}


@end
