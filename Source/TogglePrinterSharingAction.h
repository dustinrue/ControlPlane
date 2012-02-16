//
//  TogglePrinterSharing.h
//  ControlPlane
//
//  Created by Dustin Rue on 1/15/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "ToggleableAction.h"

@interface TogglePrinterSharingAction : ToggleableAction

- (NSString *) description;
- (BOOL) execute: (NSString **) errorString;
+ (NSString *) helpText;
+ (NSString *) creationHelpText;

@end
