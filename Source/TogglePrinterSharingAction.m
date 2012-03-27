//
//  TogglePrinterSharing.m
//  ControlPlane
//
//  Created by Dustin Rue on 1/15/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "TogglePrinterSharingAction.h"
#import "Action+HelperTool.h"

@implementation TogglePrinterSharingAction

- (NSString *) description {
	if (turnOn)
		return NSLocalizedString(@"Enabling Printer Sharing.", @"Act of turning on or enabling Printer Sharing is being performed");
	else
		return NSLocalizedString(@"Disabling Printer Sharing.", @"Act of turning off or disabling Printer Sharing is being performed");
}

- (BOOL) execute: (NSString **) errorString {
	NSString *command = turnOn ? @kCPHelperToolEnablePrinterSharingCommand : @kCPHelperToolDisablePrinterSharingCommand;
	
	BOOL result = [self helperToolPerformAction: command];
	
	if (!result) {
		if (turnOn)
			*errorString = NSLocalizedString(@"Failed enabling Printer Sharing.", @"Act of turning on or enabling Printer Sharing failed");
		else
			*errorString = NSLocalizedString(@"Failed disabling Printer Sharing.", @"Act of turning off or disabling Printer Sharing failed");
	}
	
	return result;
}

+ (NSString *) helpText {
	return NSLocalizedString(@"The parameter for TogglePrinterSharing actions is either \"1\" "
                             "or \"0\", depending on whether you want Printer Sharing "
                             "turned on or off.", @"");
}

+ (NSString *) creationHelpText {
	return NSLocalizedString(@"Set Printer Sharing", @"Will be followed by 'on' or 'off'");
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Toggle Printer Sharing", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"Sharing", @"");
}


@end
