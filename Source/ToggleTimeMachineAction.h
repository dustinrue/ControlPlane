//
//  ToggleTimeMachine.h
//  ControlPlane
//
//  Created by Dustin Rue on 9/3/11.
//  Copyright 2011. All rights reserved.
//

#import "ToggleableAction.h"




@interface ToggleTimeMachineAction : ToggleableAction {
   
}

- (OSStatus)doEnableTM;
- (OSStatus)doDisableTM;

@end
