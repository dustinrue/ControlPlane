//
//	CPController+SleepMonitor.m (former CPController+SleepThread.m)
//	ControlPlane
//
//	Created by David Jennes on 05/09/11.
//	Copyright 2011. All rights reserved.
//
//  Bug fix and implementation improvements by Vladimir Beloborodov (VladimirTechMan) on 21-22 July 2013.
//

#import "CPController+SleepMonitor.h"
#import "DSLogger.h"

#import <IOKit/pwr_mgt/IOPMLib.h>
#import <IOKit/IOMessage.h>
#import <IOKit/ps/IOPowerSources.h>
#import <libkern/OSAtomic.h>


// needed for sleep callback
CPController *cpController = nil;
dispatch_group_t actionsInProgress = 0;
io_connect_t rootPort = 0;
CFRunLoopSourceRef powerAdapterChanged = NULL, powerPortNotification = NULL;

static void sleepCallBack(void *refCon, io_service_t service, natural_t messageType, void *argument);
static void powerAdapterChangedCallBack();

@implementation CPController (SleepMonitor)

- (void)startMonitoringSleepAndPowerNotifications {
    if (!cpController) {
        cpController = self;
        actionsInProgress = dispatch_group_create();

        // register to receive system sleep notifications
        IONotificationPortRef notifyPort;
        io_object_t notifierObject;
        rootPort = IORegisterForSystemPower(self, &notifyPort, sleepCallBack, &notifierObject);
        if (!rootPort) {
            DSLog(@"IORegisterForSystemPower failed");
        }

        // add the notification port to the application runloop
        powerPortNotification = IONotificationPortGetRunLoopSource(notifyPort);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), powerPortNotification, kCFRunLoopCommonModes);

        powerAdapterChanged = IOPSNotificationCreateRunLoopSource(powerAdapterChangedCallBack, NULL);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), powerAdapterChanged, kCFRunLoopCommonModes);
    }
}

- (void)stopMonitoringSleepAndPowerNotifications {
    if (cpController) {
        if (powerAdapterChanged) {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), powerAdapterChanged, kCFRunLoopCommonModes);
            CFRelease(powerAdapterChanged);
            powerAdapterChanged = NULL;
        }
        if (powerPortNotification) {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), powerPortNotification, kCFRunLoopCommonModes);
            powerPortNotification = NULL;
        }
        if (actionsInProgress) {
            dispatch_release(actionsInProgress);
            actionsInProgress = 0;
        }
        cpController = nil;
    }
}

- (void)increaseActionsInProgress {
    dispatch_group_enter(actionsInProgress);
}

- (void)decreaseActionsInProgress {
    dispatch_group_leave(actionsInProgress);
}


static void sleepCallBack(void *refCon, io_service_t service, natural_t messageType, void *argument) {
	switch (messageType) {
		case kIOMessageCanSystemSleep:
		case kIOMessageSystemWillSleep:
			// entering sleep
#ifdef DEBUG_MODE
			DSLog(@"Sleep callback: going to sleep");
#endif

            [[NSNotificationCenter defaultCenter] postNotificationName:@"systemWillSleep" object:nil];

#ifdef DEBUG_MODE
			DSLog(@"Sleep callback: force calling doUpdateForReal");
#endif

            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"EnableSwitchSmoothing"]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [cpController->updatingLock lockWhenCondition:0];
                    [cpController->updatingLock unlockWithCondition:1];
                });
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                [cpController->updatingLock lockWhenCondition:0];
                [cpController->updatingLock unlockWithCondition:1];

                dispatch_group_wait(actionsInProgress, DISPATCH_TIME_FOREVER);
                
                IOAllowPowerChange(rootPort, (long)argument); // Allow sleep
            });

			break;

		case kIOMessageSystemWillPowerOn:
			DSLog(@"Sleep callback: waking up");
            [[NSNotificationCenter defaultCenter] postNotificationName:@"systemDidWake" object:nil];
			break;

		case kIOMessageSystemHasPoweredOn:
			break;

		default:
			break;
	}
}

static void powerAdapterChangedCallBack() {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"powerAdapterDidChangeNotification" object:nil];
}

@end
