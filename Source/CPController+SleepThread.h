//
//  CPController+SleepThread.h
//  ControlPlane
//
//  Created by David Jennes on 05/09/11.
//  Copyright 2011. All rights reserved.
//

#import "CPController.h"

@interface CPController (SleepThread)

- (void) monitorSleepThread: (id) arg;
- (void) increaseActionsInProgress;
- (void) decreaseActionsInProgress;

@end
