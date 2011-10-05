//
//	PowerSource.m
//	ControlPlane
//
//	Created by David Jennes on 21/09/11.
//	Copyright 2011. All rights reserved.
//

#import "PowerSource.h"
#include <IOKit/IOMessage.h>
#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>

static void sourceChange(void *info);
static void displayChange(void *context, io_service_t y, natural_t msgType, void *msgArgument);

@implementation PowerSource

@synthesize displayState = m_displayState;
@synthesize powerSource = m_powerSource;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	self.displayState = kDisplayOn;
	self.powerSource = kPowerError;
	m_runLoopSource = nil;
	m_runLoopDisplay = nil;
	
	return self;
}

#pragma mark - Required implementation of 'CallbackSource' class

- (NSArray *) observableKeys {
	return [NSArray arrayWithObjects: @"displayState", @"powerSource", nil];
}

- (void) registerCallback {
	io_service_t wrangler;
	IONotificationPortRef port;
	io_object_t notifier;
	
	// power source callback
	m_runLoopSource = IOPSNotificationCreateRunLoopSource(sourceChange, self);
	
	// display callback
	wrangler = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceNameMatching("IODisplayWrangler"));
	ZAssert(wrangler, @"IOServiceGetMatchingService failed");
	port = IONotificationPortCreate(kIOMasterPortDefault);
	ZAssert(port, @"IONotificationPortCreate failed");
	
	kern_return_t kr = IOServiceAddInterestNotification(port, wrangler, kIOGeneralInterest, displayChange, self, &notifier);
	ZAssert(kr == kIOReturnSuccess, @"IOServiceAddInterestNotification failed");
	
	m_runLoopDisplay = IONotificationPortGetRunLoopSource(port);
	IOObjectRelease (wrangler);
	
	// add to runloop
	CFRunLoopAddSource(CFRunLoopGetCurrent(), m_runLoopSource, kCFRunLoopDefaultMode);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), m_runLoopDisplay, kCFRunLoopDefaultMode);
}

- (void) unregisterCallback {
	// Unregister listener
	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), m_runLoopSource, kCFRunLoopDefaultMode);
	CFRelease(m_runLoopSource);
	
	self.powerSource = kPowerError;
}

- (void) checkData {
	BOOL batteryFound = NO;
	BOOL acFound = NO;
	CFTypeRef source;
	
	// get list of power sources
	CFTypeRef blob = IOPSCopyPowerSourcesInfo();
	NSArray *list = [(NSArray *) IOPSCopyPowerSourcesList(blob) autorelease];
	
	// loop through list
	NSEnumerator *en = [list objectEnumerator];
	while ((source = [en nextObject])) {
		NSDictionary *dict = (NSDictionary *) IOPSGetPowerSourceDescription(blob, source);
		NSString *value = [dict valueForKey: @kIOPSPowerSourceStateKey];
		
		if ([value isEqualToString: @kIOPSACPowerValue])
			acFound = YES;
		else if ([value isEqualToString: @kIOPSBatteryPowerValue])
			batteryFound = YES;
	}
	
	// result
	CFRelease(blob);
	BOOL result = (batteryFound ? kPowerBattery : (acFound ? kPowerAC : kPowerError));
	
	// store it
	if (self.powerSource != result)
		self.powerSource = result;
}

#pragma mark - Internal callbacks

static void sourceChange(void *info) {
	PowerSource *src = (PowerSource *) info;
	
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	[src checkData];
	[pool release];
}

static void displayChange(void *context, io_service_t y, natural_t msgType, void *msgArgument) {
	PowerSource *src = (PowerSource *) msgArgument;
	
	switch (msgType) {
		case kIOMessageDeviceWillPowerOff:
			if (src.displayState == kDisplayOn)
				src.displayState = kDisplayDimmed;
			else
				src.displayState = kDisplayOff;
			break;
		case kIOMessageDeviceHasPoweredOn:
			src.displayState = kDisplayOn;
			break;
	}
}

@end
