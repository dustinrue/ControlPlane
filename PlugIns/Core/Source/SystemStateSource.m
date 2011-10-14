//
//  SystemStateSource.m
//  ControlPlane
//
//  Created by David Jennes on 30/09/11.
//  Copyright 2011. All rights reserved.
//

#import "SystemStateSource.h"
#import <IOKit/IOMessage.h>
#import <IOKit/pwr_mgt/IOPMLib.h>

static void powerCallback(void *rootPort, io_service_t y, natural_t msgType, void *msgArgument);

@interface SystemStateSource (Private)

- (void) workspaceWillPowerOff: (NSNotification *) notification;

@end

@implementation SystemStateSource

@synthesize state = m_state;
@synthesize allowSleep = m_allowSleep;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	self.state = kSystemNormal;
	self.allowSleep = YES;
	
	return self;
}

#pragma mark - Required implementation of 'CallbackSource' class

- (NSArray *) observableKeys {
	return [NSArray arrayWithObject: @"state"];
}

- (void) registerCallback {
	// sleep
	m_rootPort = IORegisterForSystemPower((__bridge void *) self, &m_notifyPort, powerCallback, &m_notifierObject);
	CFRunLoopSourceRef runLoopSource = IONotificationPortGetRunLoopSource(m_notifyPort);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
	
	// poweroff
	[NSNotificationCenter.defaultCenter addObserver: self
										   selector: @selector(workspaceWillPowerOff:)
											   name: @"NSWorkspaceWillPowerOffNotification"
											 object: nil];
}

- (void) unregisterCallback {
	CFRunLoopSourceRef runLoopSource = IONotificationPortGetRunLoopSource(m_notifyPort);
	
	// sleep
	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
	IODeregisterForSystemPower(&m_notifierObject);
	IOServiceClose(m_rootPort);
	IONotificationPortDestroy(m_notifyPort);
	
	// poweroff
	[NSNotificationCenter.defaultCenter removeObserver: self];
	
	self.state = kSystemNormal;
}

- (void) checkData {
	if (self.state != kSystemNormal)
		self.state = kSystemNormal;
}

#pragma mark - Internal callbacks

void powerCallback(void *refCon, io_service_t service, natural_t msgType, void *msgArgument) {
	SystemStateSource *source = (__bridge SystemStateSource *) refCon;
	eSystemState result = kSystemNormal;
	
	switch (msgType) {
		case kIOMessageCanSystemSleep:
		case kIOMessageSystemWillSleep:
			source.allowSleep = NO;
			result = kSystemSleep;
			break;
		case kIOMessageSystemWillPowerOn:
			result = kSystemWake;
			break;
		case kIOMessageSystemHasPoweredOn:
			result = kSystemNormal;
			break;
	}
	
	// store result
	if (source.state != result)
		source.state = result;
	
	// wait to allow sleep if needed
	if (result == kSystemSleep) {
		for (unsigned i = 0; i < 20 && !source.allowSleep; ++i)
			[NSThread sleepForTimeInterval: 1];
		
		IOAllowPowerChange(source->m_rootPort, (long) msgArgument);
	}
}

- (void) workspaceWillPowerOff: (NSNotification *) notification {
	self.state = kSystemPowerOff;
}

@end
