//
//  ToggleTimeMachine.m
//  ControlPlane
//
//  Created by Dustin Rue on 3/9/11.
//  Copyright 2011. All rights reserved.
//

#import "ToggleTimeMachineAction.h"
#import "Action+HelperTool.h"

@implementation ToggleTimeMachineAction

- (NSString *) description {
	if (turnOn)
		return NSLocalizedString(@"Enabling Time Machine.", @"Act of turning on or enabling Time Machine backup system is being performed");
	else
		return NSLocalizedString(@"Disabling Time Machine.", @"Act of turning off or disabling Time Machine backup system is being performed");
}

- (BOOL) execute: (NSString **) errorString {
	NSString *command = turnOn ? @kCPHelperToolEnableTMCommand : @kCPHelperToolDisableTMCommand;
	
	BOOL result = [self helperToolPerformAction: command];
	
	if (!result) {
		if (turnOn)
			*errorString = NSLocalizedString(@"Failed enabling Time Machine.", @"Act of turning on or enabling Time Machine backup system failed");
		else
			*errorString = NSLocalizedString(@"Failed disabling Time Machine.", @"Act of turning off or disabling Time Machine backup system failed");
	}
	
	return result;
}

+ (NSString *) helpText {
	return NSLocalizedString(@"The parameter for ToggleTimeMachine actions is either \"1\" "
                             "or \"0\", depending on whether you want to enable or disable Time Machine "
                             "turned on or off.", @"");
}

+ (NSString *) creationHelpText {
	return NSLocalizedString(@"Set Time Machine", @"Will be followed by 'on' or 'off'");
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Toggle Time Machine", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"Time Machine", @"");
}

@end
