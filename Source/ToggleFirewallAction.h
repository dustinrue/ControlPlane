//
//  ToggleFirewallAction.h
//  ControlPlane
//
//  Created by Dustin Rue on 10/20/11.
//  Copyright (c) 2011. All rights reserved.
//
//  Inspired by - http://krypted.com/mac-os-x/command-line-alf-redux/
//

#import "ToggleableAction.h"


@interface ToggleFirewallAction : ToggleableAction

- (NSString *) description;
- (BOOL) execute: (NSString **) errorString;
+ (NSString *) helpText;
+ (NSString *) creationHelpText;

@end
