//
//  CPController+SleepMonitor.h (former CPController+SleepThread.h)
//  ControlPlane
//
//  Created by David Jennes on 05/09/11.
//  Copyright 2011. All rights reserved.
//
//  Bug fix and implementation improvements by Vladimir Beloborodov (VladimirTechMan) on 21-22 July 2013.
//

#import "CPController.h"

@interface CPController (SleepMonitor)

- (void)startMonitoringSleepAndPowerNotifications;
- (void)stopMonitoringSleepAndPowerNotifications;

- (void) increaseActionsInProgress;
- (void) decreaseActionsInProgress;

@end
