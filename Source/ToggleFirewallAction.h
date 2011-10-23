//
//  ToggleFirewallAction.h
//  ControlPlane
//
//  Created by Dustin Rue on 10/20/11.
//  Copyright (c) 2011. All rights reserved.
//

#import "ToggleableAction.h"


@interface ToggleFirewallAction : ToggleableAction

- (NSString *) description;
- (BOOL) execute: (NSString **) errorString;
+ (NSString *) helpText;
+ (NSString *) creationHelpText;

@end
