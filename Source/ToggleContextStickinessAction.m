//
//  ToggleContextStickinessAction.m
//  ControlPlane
//
//  Created by Dustin Rue on 8/15/12.
//
//

#import "ToggleContextStickinessAction.h"

@implementation ToggleContextStickinessAction

- (NSString *) description {
	if (turnOn)
		return NSLocalizedString(@"Enabling ControlPlane Context is Sticky.", @"Act of turning on or enabling ControlPlane Context is Sticky is being performed");
	else
		return NSLocalizedString(@"Disabling ControlPlane Context is Sticky.", @"Act of turning off or disabling ControlPlane Context is Sticky is being performed");
}

- (BOOL) execute: (NSString **) errorString {
    BOOL success = YES;
    
    if (turnOn) {
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"setStickyBit" object:nil];
        
    }
    else {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"unsetStickyBit" object:nil];
    }
    
    return success;
}

+ (NSString *) helpText {
	return NSLocalizedString(@"The parameter for ToggleContextStickiness actions is either \"1\" "
                             "or \"0\", depending on whether you want ControlPlane Context is Sticky "
                             "turned on or off.", @"");
}

+ (NSString *) creationHelpText {
	return NSLocalizedString(@"Set ControlPlane Context is Sticky", @"Will be followed by 'on' or 'off'");
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Toggle ControlPlane Context is Sticky", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"Application", @"");
}

@end
