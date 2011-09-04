//
//  ToggleTimeMachine.h
//  ControlPlane
//
//  Created by Dustin Rue on 9/3/11.
//  Copyright 2011. All rights reserved.
//

#import "ToggleableAction.h"

@interface ToggleTimeMachineAction : ToggleableAction

- (NSString *) description;
- (BOOL) execute: (NSString **) errorString;
+ (NSString *) helpText;
+ (NSString *) creationHelpText;

@end
