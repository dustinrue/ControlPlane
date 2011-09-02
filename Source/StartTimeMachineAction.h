//
//  StartTimeMachineAction.h
//  ControlPlane
//
//  Created by David Jennes on 02/09/11.
//  Copyright 2011. All rights reserved.
//

#import "ToggleableAction.h"

@interface StartTimeMachineAction : ToggleableAction

- (NSString *) description;
- (BOOL) execute: (NSString **) errorString;
+ (NSString *) helpText;
+ (NSString *) creationHelpText;
+ (NSArray *) limitedOptions;

@end
