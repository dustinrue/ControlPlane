//
//  ToggleFirewallAction.m
//  ControlPlane
//
//  Created by Dustin Rue on 10/20/11.
//  Copyright (c) 2011. All rights reserved.
//
//  Inspired by - http://krypted.com/mac-os-x/command-line-alf-redux/
//

#import "ToggleFirewallAction.h"
#import "Action+HelperTool.h"

@implementation ToggleFirewallAction


- (NSString *) description {
	if (turnOn)
		return NSLocalizedString(@"Enabling Firewall.", @"Act of turning on or enabling the firewall is being performed");
	else
		return NSLocalizedString(@"Disabling Firewall.", @"Act of turning off or disabling the firewall is being performed");
}

- (BOOL) execute: (NSString **) errorString {
	BOOL result = [CAction helperToolPerformAction: @kCPHelperToolSetEnabledFWCommand
									 withParameter: [NSNumber numberWithBool: turnOn]];
	
	if (!result) {
		if (turnOn)
			*errorString = NSLocalizedString(@"Failed enabling firewall.", @"Act of turning on or enabling the firewall failed");
		else
			*errorString = NSLocalizedString(@"Failed disabling firewall.", @"Act of turning off or disabling the firewall failed");
	}
	
	return result;
}

+ (NSString *) helpText {
	return NSLocalizedString(@"The parameter for the Firewall action is either \"1\" "
                             "or \"0\", depending on whether you want to enable or disable the firewall."
                             "", @"");
}

+ (NSString *) creationHelpText {
	return NSLocalizedString(@"Turn Firewall", @"Will be followed by 'on' or 'off'");
}

@end
