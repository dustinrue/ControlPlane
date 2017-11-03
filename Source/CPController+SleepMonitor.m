//
//	CPController+SleepMonitor.m (former CPController+SleepThread.m)
//	ControlPlane
//
//	Created by David Jennes on 05/09/11.
//	Copyright 2011. All rights reserved.
//
//  Bug fix and implementation improvements by Vladimir Beloborodov (VladimirTechMan) on 21-22 July 2013.
//  Major rework done by Vladimir Beloborodov (VladimirTechMan) on 29 August 2913.
//
//  IMPORTANT: This code is intended to be compiled for the ARC mode
//

#import "CPNotifications.h"
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
        rootPort = IORegisterForSystemPower((__bridge void *)(self), &notifyPort, sleepCallBack, &notifierObject);
        if (!rootPort) {
            DSLog(@"IORegisterForSystemPower failed");
        }

        // add the notification port to the application runloop
        powerPortNotification = IONotificationPortGetRunLoopSource(notifyPort);
        CFRunLoopAddSource(CFRunLoopGetMain(), powerPortNotification, kCFRunLoopCommonModes);

        powerAdapterChanged = IOPSNotificationCreateRunLoopSource(powerAdapterChangedCallBack, NULL);
        CFRunLoopAddSource(CFRunLoopGetMain(), powerAdapterChanged, kCFRunLoopCommonModes);
    }
}

- (void)stopMonitoringSleepAndPowerNotifications {
    if (cpController) {
        if (powerAdapterChanged) {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), powerAdapterChanged, kCFRunLoopCommonModes);
            CFRelease(powerAdapterChanged);
            powerAdapterChanged = NULL;
        }
        if (powerPortNotification) {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), powerPortNotification, kCFRunLoopCommonModes);
            powerPortNotification = NULL;
        }
        if (actionsInProgress) {
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


static void powerAdapterChangedCallBack() {
#ifdef DEBUG_MODE
    DSLog(@"System notification on power adapter change");
#endif
    [[NSNotificationCenter defaultCenter] postNotificationName:@"powerAdapterDidChangeNotification" object:nil];
}

static void sleepCallBack(void *refCon, io_service_t service, natural_t messageType, void *argument) {
	switch (messageType) {
		case kIOMessageCanSystemSleep:
            // ControlPlane does not veto an idle system sleep. But any other app may still cancel it.
            IOAllowPowerChange(rootPort, (long)argument);
            break;
            
		case kIOMessageSystemWillSleep:
			DSLog(@"System sleep callback: going to sleep");
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"systemWillSleep" object:nil];
            
            [cpController restartSwitchSmoothing];
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"EnableSwitchSmoothing"]) {
                [cpController forceUpdate];
            }
            [cpController forceUpdate];
            
            dispatch_group_notify(actionsInProgress, dispatch_get_main_queue(), ^{
                IOAllowPowerChange(rootPort, (long)argument);
#ifdef DEBUG_MODE
                DSLog(@"System sleep callback: Allowed power change on system sleep");
#endif
            });
            
			break;
            
		case kIOMessageSystemWillPowerOn:
            // System h/w and drivers are not (guaranteed to be) ready at this point yet.
            // Wait until kIOMessageSystemHasPoweredOn.
			break;
            
		case kIOMessageSystemHasPoweredOn:
            if (dispatch_group_wait(actionsInProgress, DISPATCH_TIME_NOW) != 0) {
                DSLog(@"Some actions took too long to be fully executed before system sleep."
                      " Thus they were resumed and completed on system wake-up.");
                
                NSString *title = NSLocalizedString(@"Information", @"Title for informational user messsages");
                NSString *msg = NSLocalizedString(@"Some actions took too long to finish before system sleep",
                                                  @"Shown when some actions did not finish before system sleep");
                [CPNotifications postUserNotification:title withMessage:msg];
            }
            
            DSLog(@"System sleep callback: waking up");
            [[NSNotificationCenter defaultCenter] postNotificationName:@"systemDidWake" object:nil];
			break;
            
		default:
			break;
	}
}

@end
