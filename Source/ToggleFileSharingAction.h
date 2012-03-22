//
//  ToggleFileSharingAction.h
//  ControlPlane
//
//  Created by Dustin Rue on 3/17/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "Action.h"

enum FileSharingOptions {
    kCPAFPEnable,
    kCPSMBEnable,
    kCPAFPAndSMBEnable,
    kCPAFPDisable,
    kCPSMBDisable,
    kCPAFPAndSMBDisable
};

@interface ToggleFileSharingAction : Action <ActionWithLimitedOptions> {
    NSNumber *turnOn;
}

- (NSString *) description;
- (BOOL) execute: (NSString **) errorString;
+ (NSString *) helpText;
+ (NSString *) creationHelpText;

@end
