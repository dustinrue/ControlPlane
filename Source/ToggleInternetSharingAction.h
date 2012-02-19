//
//  ToggleInternetSharingAction.h
//  ControlPlane
//
//  Created by Dustin Rue on 19/10/11.
//  Copyright (c) 2011. All rights reserved.
//

#import "ToggleableAction.h"

@interface ToggleInternetSharingAction : ToggleableAction
    - (NSString *) description;
    - (BOOL) execute: (NSString **) errorString;
    + (NSString *) helpText;
    + (NSString *) creationHelpText;
@end

