//
//  SleepSource.m
//  ControlPlane
//
//  Created by David Jennes on 30/09/11.
//  Copyright 2011. All rights reserved.
//

#import "SleepSource.h"
#import <IOKit/IOMessage.h>
#import <IOKit/pwr_mgt/IOPMLib.h>

static void powerCallback(void *rootPort, io_service_t y, natural_t msgType, void *msgArgument);

@implementation SleepSource

registerSourceType(SleepSource)
@synthesize state = m_state;
@synthesize allowSleep = m_allowSleep;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	self.state = kSleepNormal;
	self.allowSleep = YES;
	
	return self;
}

#pragma mark - Required implementation of 'CallbackSource' class

- (NSArray *) observableKeys {
	return [NSArray arrayWithObject: @"state"];
}

- (void) registerCallback {
	// register
	m_rootPort = IORegisterForSystemPower(self, &m_notifyPort, powerCallback, &m_notifierObject);
	CFRunLoopSourceRef runLoopSource = IONotificationPortGetRunLoopSource(m_notifyPort);
	
	CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
}

- (void) unregisterCallback {
	CFRunLoopSourceRef runLoopSource = IONotificationPortGetRunLoopSource(m_notifyPort);
	
	// unregister
	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
	IODeregisterForSystemPower(&m_notifierObject);
	IOServiceClose(m_rootPort);
	IONotificationPortDestroy(m_notifyPort);
	
	self.state = kSleepNormal;
}

- (void) checkData {
	self.state = kSleepNormal;
}

#pragma mark - Internal callbacks

void powerCallback(void *refCon, io_service_t service, natural_t msgType, void *msgArgument) {
	SleepSource *source = (SleepSource *) refCon;
	
	switch (msgType) {
		case kIOMessageCanSystemSleep:
		case kIOMessageSystemWillSleep:
			source.allowSleep = NO;
			source.state = kSleepSleep;
			
			// wait for 20 seconds or until allowed to sleep
			for (unsigned i = 0; i < 20 && !source.allowSleep; ++i)
				[NSThread sleepForTimeInterval: 1];
			
			IOAllowPowerChange(source->m_rootPort, (long) msgArgument);
			break;
		case kIOMessageSystemWillPowerOn:
			source.state = kSleepWake;
			break;
		case kIOMessageSystemHasPoweredOn:
			source.state = kSleepNormal;
			break;
	}
}

@end
