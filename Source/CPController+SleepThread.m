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
#import <libkern/OSAtomic.h>


// needed for sleep callback
CPController *cp_controller = nil;
int32_t actionsInProgress = 0;
io_connect_t root_port = 0;
void sleepCallBack(void *refCon, io_service_t service, natural_t messageType, void *argument);


@implementation CPController (SleepThread)

- (void) monitorSleepThread: (id) arg {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	IONotificationPortRef notifyPort; 
	io_object_t notifierObject; 
	cp_controller = self;
	
	// register to receive system sleep notifications
	root_port = IORegisterForSystemPower(self, &notifyPort, sleepCallBack, &notifierObject);
	if (!root_port)
		DSLog(@"IORegisterForSystemPower failed");
	
	// add the notification port to the application runloop
	CFRunLoopAddSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(notifyPort), kCFRunLoopCommonModes);
	
	// run!
	CFRunLoopRun();
	[pool release];
}

- (void) increaseActionsInProgress {
	OSAtomicIncrement32(&actionsInProgress);
}

- (void) decreaseActionsInProgress {
	OSAtomicDecrement32(&actionsInProgress);
}

void sleepCallBack(void *refCon, io_service_t service, natural_t messageType, void *argument) {
	BOOL smoothing = [[NSUserDefaults standardUserDefaults] boolForKey:@"EnableSwitchSmoothing"];

	switch (messageType) {
		case kIOMessageCanSystemSleep:
		case kIOMessageSystemWillSleep:
			// entering sleep
			DSLog(@"Sleep callback: going to sleep (isMainThread=%@, thread=%@)", [NSThread isMainThread] ? @"YES" : @"NO", [NSThread currentThread]);
			
			// Hack: we need to do an extra check (2 if smoothing is enabled) right before sleeping
			//		 otherwise the sleep rule won't be triggered
			[NSThread sleepForTimeInterval:2];
			
			// Call update for real (in case of smoothing, call twice)
			DSLog(@"Sleep callback: calling doUpdateForReal");
			[cp_controller doUpdateForReal];
			if (smoothing)
				[cp_controller doUpdateForReal];
			
			// wait until all actions finish
			while (actionsInProgress > 0)
				usleep(100);
			
			// Allow sleep
			IOAllowPowerChange(root_port, (long)argument);
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

@end
