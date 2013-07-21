//
//	CPController+SleepThread.m
//	ControlPlane
//
//	Created by David Jennes on 05/09/11.
//	Copyright 2011. All rights reserved.
//
//  Bug fix and code improvements by Vladimir Beloborodov (VladimirTechMan) on 21 July 2013.
//

#import "CPController+SleepThread.h"
#import "DSLogger.h"

#import <IOKit/pwr_mgt/IOPMLib.h>
#import <IOKit/IOMessage.h>
#import <IOKit/ps/IOPowerSources.h>
#import <libkern/OSAtomic.h>


// needed for sleep callback
CPController *cpController = nil;
dispatch_group_t actionsInProgress;
io_connect_t rootPort = 0;

static void sleepCallBack(void *refCon, io_service_t service, natural_t messageType, void *argument);
static void powerAdapterChangedCallBack();


@implementation CPController (SleepThread)

- (void)monitorSleepThread:(id)arg {
    @autoreleasepool {
        actionsInProgress = dispatch_group_create();
        cpController = self;

        // register to receive system sleep notifications
        IONotificationPortRef notifyPort;
        io_object_t notifierObject;
        rootPort = IORegisterForSystemPower(self, &notifyPort, sleepCallBack, &notifierObject);
        if (!rootPort) {
            DSLog(@"IORegisterForSystemPower failed");
        }
        
        // add the notification port to the application runloop
        CFRunLoopAddSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(notifyPort), kCFRunLoopCommonModes);
        
        CFRunLoopSourceRef powerAdapterChanged = IOPSNotificationCreateRunLoopSource(powerAdapterChangedCallBack, NULL);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), powerAdapterChanged, kCFRunLoopCommonModes);
        // run!
        CFRunLoopRun();
        
        dispatch_release(actionsInProgress);
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
			DSLog(@"Sleep callback: going to sleep (isMainThread=%@, thread=%@)", [NSThread isMainThread] ? @"YES" : @"NO", [NSThread currentThread]);
#endif

            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"systemWillSleep" object:nil];
            });

#ifdef DEBUG_MODE
			DSLog(@"Sleep callback: force calling doUpdateForReal");
#endif

            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"EnableSwitchSmoothing"]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [cpController->updatingLock lockWhenCondition:0];
                    [cpController->updatingLock unlockWithCondition:1];
                });
            }

            [cpController increaseActionsInProgress];
            dispatch_async(dispatch_get_main_queue(), ^{
                [cpController->updatingLock lockWhenCondition:0];
                [cpController->updatingLock unlockWithCondition:1];
                [cpController decreaseActionsInProgress];
            });

            dispatch_group_wait(actionsInProgress, DISPATCH_TIME_FOREVER);

			// Allow sleep
			IOAllowPowerChange(rootPort, (long)argument);
			break;

		case kIOMessageSystemWillPowerOn:
			DSLog(@"Sleep callback: waking up");
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"systemDidWake" object:nil];
            });
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
