//
//	CPController+SleepThread.m
//	ControlPlane
//
//	Created by David Jennes on 05/09/11.
//	Copyright 2011. All rights reserved.
//

#import "CPController+SleepThread.h"
#import "DSLogger.h"

#import <IOKit/pwr_mgt/IOPMLib.h>
#import <IOKit/IOMessage.h>
#import <IOKit/ps/IOPowerSources.h>
#import <libkern/OSAtomic.h>


// needed for sleep callback
CPController *cp_controller = nil;
dispatch_group_t actionsInProgress;
io_connect_t root_port = 0;
CFRunLoopSourceRef powerAdapterChanged = nil;
void sleepCallBack(void *refCon, io_service_t service, natural_t messageType, void *argument);
static void powerAdapterChangedCallBack();


@implementation CPController (SleepThread)

- (void) monitorSleepThread: (id) arg {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    actionsInProgress = dispatch_group_create();

	IONotificationPortRef notifyPort; 
	io_object_t notifierObject; 
	cp_controller = self;

	// register to receive system sleep notifications
	root_port = IORegisterForSystemPower(self, &notifyPort, sleepCallBack, &notifierObject);
	if (!root_port) {
		DSLog(@"IORegisterForSystemPower failed");
    }

	// add the notification port to the application runloop
	CFRunLoopAddSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(notifyPort), kCFRunLoopCommonModes);
    powerAdapterChanged = IOPSNotificationCreateRunLoopSource(
                                                           powerAdapterChangedCallBack,
                                                           NULL);
	
    CFRunLoopAddSource(CFRunLoopGetCurrent(), powerAdapterChanged, kCFRunLoopCommonModes);
	// run!
	CFRunLoopRun();

    dispatch_release(actionsInProgress);
	[pool release];
}

- (void)increaseActionsInProgress {
    dispatch_group_enter(actionsInProgress);
}

- (void)decreaseActionsInProgress {
    dispatch_group_leave(actionsInProgress);
}


void sleepCallBack(void *refCon, io_service_t service, natural_t messageType, void *argument) {
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
                    [cp_controller->updatingLock lockWhenCondition:0];
                    [cp_controller->updatingLock unlockWithCondition:1];
                });
            }

            [cp_controller increaseActionsInProgress];
            dispatch_async(dispatch_get_main_queue(), ^{
                [cp_controller->updatingLock lockWhenCondition:0];
                [cp_controller->updatingLock unlockWithCondition:1];
                [cp_controller decreaseActionsInProgress];
            });

            dispatch_group_wait(actionsInProgress, DISPATCH_TIME_FOREVER);

			// Allow sleep
			IOAllowPowerChange(root_port, (long)argument);
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
