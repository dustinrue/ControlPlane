//
//	StartTimeMachineAction.m
//	ControlPlane
//
//	Created by David Jennes on 02/09/11.
//	Copyright 2011. All rights reserved.
//

#import "StartTimeMachineAction.h"

@implementation StartTimeMachineAction


- (NSString *) description {
	if (turnOn)
		return NSLocalizedString(@"Starting Time Machine backup.", @"");
	else
		return NSLocalizedString(@"Stopping Time Machine backup.", @"");
}

- (BOOL) execute: (NSString **) errorString {
	if (turnOn)
		[NSTask launchedTaskWithLaunchPath: @"/System/Library/CoreServices/backupd.bundle/Contents/Resources/backupd-helper"
								 arguments: [NSArray array]];
	else
		// TODO: this should actually be done with root privileges
		//		 now we can only kill backups we have started ourselves
		[NSTask launchedTaskWithLaunchPath: @"/usr/bin/killall"
								 arguments: [NSArray arrayWithObjects: @"backupd-helper", nil]];
	
	return YES;
}

+ (NSString *) helpText {
	return NSLocalizedString(@"The parameter for StartTimeMachine actions is either \"1\" "
							 "or \"0\", depending on whether you want start or stop a "
							 "Time Machine backup.", @"");
}

+ (NSString *) creationHelpText {
	return @"Start or stop a Time Machine backup?";
}

+ (NSArray *) limitedOptions {
	return [NSArray arrayWithObjects:
			[NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithBool: YES], @"option",
			 NSLocalizedString(@"Start backup", @""), @"description", nil],
			[NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithBool: NO], @"option",
			 NSLocalizedString(@"Stop backup", @""), @"description", nil],
			nil];
}

@end
