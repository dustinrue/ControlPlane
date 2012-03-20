//
//  ToggleFileSharingAction.m
//  ControlPlane
//
//  Created by Dustin Rue on 3/17/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "ToggleFileSharingAction.h"
#import "Action+HelperTool.h"

@implementation ToggleFileSharingAction

- (NSString *) description {
	if (turnOn)
		return NSLocalizedString(@"Enabling File Sharing.", @"Act of turning on or enabling File Sharing is being performed");
	else
		return NSLocalizedString(@"Disabling File Sharing.", @"Act of turning off or disabling File Sharing is being performed");
}

- (BOOL) execute: (NSString **) errorString {
    
    BOOL failed = NO;
    
    failed = [self helperToolPerformAction:@kCPHelperToolGetFileSharingConfigCommand withParameter:@"com.apple.AppleFileServer"];
    
    if (failed)
        NSLog(@"failed to get AFP status");
    
    NSLog(@"%@", response);
    
    failed = [self helperToolPerformAction:@kCPHelperToolGetFileSharingConfigCommand withParameter:@"com.apple.smbd"];
    
    if (failed)
        NSLog(@"failed to get smbd status");
    
    NSLog(@"%@", response);
    /*
	NSString *command = turnOn ? @kCPHelperToolEnableFileSharingCommand : @kCPHelperToolDisableFileSharingCommand;
    
    command = @kCPHelperToolGetFileSharingConfigCommand;
	
	BOOL result = [self helperToolPerformAction: command];
	
	if (!result) {
		if (turnOn)
			*errorString = NSLocalizedString(@"Failed enabling File Sharing.", @"Act of turning on or enabling File Sharing failed");
		else
			*errorString = NSLocalizedString(@"Failed disabling File Sharing.", @"Act of turning off or disabling File Sharing failed");
	}

    NSLog(@"response is %@", response);
    */
	return failed;
}

+ (NSString *) helpText {
	return NSLocalizedString(@"The parameter for ToggleFileSharing actions is either \"1\" "
                             "or \"0\", depending on whether you want File Sharing "
                             "turned on or off.", @"");
}

+ (NSString *) creationHelpText {
	return NSLocalizedString(@"Set File Sharing", @"Will be followed by 'on' or 'off'");
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Toggle File Sharing", @"");
}


@end
