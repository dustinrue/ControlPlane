//
//  ToggleTimeMachine.m
//  ControlPlane
//
//  Created by Dustin Rue on 9/3/11.
//  Copyright 2011. All rights reserved.
//

#import "ToggleTimeMachineAction.h"

@implementation ToggleTimeMachineAction

- (NSString *) description {
	if (turnOn)
		return NSLocalizedString(@"Enabling Time Machine.", @"Act of turning on or enabling Time Machine backup system is being performed");
	else
		return NSLocalizedString(@"Disabling Time Machine.", @"Act of turning off or disabling Time Machine backup system is being performed");
}

- (BOOL) execute: (NSString **) errorString {
	NSString *command = turnOn ? @kCPHelperToolEnableTMCommand : @kCPHelperToolDisableTMCommand;
	
	// perform command on the mainthread because of the dangers of presenting NSAlert on a 
    // separate thread
    [self performSelectorOnMainThread: @selector(helperPerformAction:) withObject: command waitUntilDone: YES];
    
	if (helperError) {
		if (turnOn)
			*errorString = NSLocalizedString(@"Failed enabling Time Machine.", @"");
		else
			*errorString = NSLocalizedString(@"Failed disabling Time Machine.", @"");
	}
	
	return (helperError ? NO : YES);
}

+ (NSString *) helpText {
	return NSLocalizedString(@"The parameter for ToggleTimeMachine actions is either \"1\" "
                             "or \"0\", depending on whether you want to enable or disable Time Machine "
                             "turned on or off.", @"");
}

+ (NSString *) creationHelpText {
	return NSLocalizedString(@"Set Time Machine", @"Will be followed by 'on' or 'off'");
}

@end
