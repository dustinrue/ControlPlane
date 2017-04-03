//
//  ToggleAutomaticSwitching.m
//  ControlPlane
//
//  Created by Dustin Rue on 4/2/17.
//
//

#import "ToggleAutomaticSwitchingAction.h"

@implementation ToggleAutomaticSwitchingAction
- (NSString *) description {
    if (turnOn)
        return NSLocalizedString(@"Enabling ControlPlane Automatic Switching.", @"Act of turning on or enabling ControlPlane Automatic Switching is being performed");
    else
        return NSLocalizedString(@"Disabling ControlPlane Automatic Switching.", @"Act of turning off or disabling ControlPlane Automatic is being performed");
}

- (BOOL) execute: (NSString **) errorString {
    BOOL success = YES;
    
    if (turnOn) {
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"enableAutomaticSwitching" object:nil];
        
    }
    else {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"disableAutomaticSwitching" object:nil];
    }
    
    return success;
}

+ (NSString *) helpText {
    return NSLocalizedString(@"The parameter for ToggleAutomaticSwitching actions is either \"1\" "
                             "or \"0\", depending on whether you want ControlPlane Automatic Switching "
                             "turned on or off.", @"");
}

+ (NSString *) creationHelpText {
    return NSLocalizedString(@"Set ControlPlane Automatic Switching", @"Will be followed by 'on' or 'off'");
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Toggle ControlPlane Automatic Switching", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"Application", @"");
}
@end
