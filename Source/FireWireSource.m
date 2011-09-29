//
//  FireWireSource.m
//  ControlPlane
//
//  Created by David Jennes on 29/09/11.
//  Copyright 2011. All rights reserved.
//

#import "FireWireSource.h"

static void cDevAdded(void *ref, io_iterator_t iterator);
static void cDevRemoved(void *ref, io_iterator_t iterator);

@interface FireWireSource (Private)

- (void) devAdded: (io_iterator_t) iterator;
- (void) devRemoved: (io_iterator_t) iterator;
- (NSNumber *) guidForDevice: (io_service_t *) device;
- (NSString *) nameForDevice: (io_service_t *) device;
- (NSString *) vendorForDevice: (io_service_t *) device;

@end

@implementation FireWireSource

registerSourceType(FireWireSource)
@synthesize devices = m_devices;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	self.devices = [[NSDictionary new] autorelease];
	
	return self;
}

- (void) dealloc {
	
	[super dealloc];
}

#pragma mark - Required implementation of 'CallbackSource' class

- (NSArray *) observableKeys {
	return [NSArray arrayWithObject: @"devices"];
}

- (void) registerCallback {
	m_notificationPort = IONotificationPortCreate(kIOMasterPortDefault);
	m_runLoopSource = IONotificationPortGetRunLoopSource(m_notificationPort);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), m_runLoopSource, kCFRunLoopDefaultMode);
	
	// Only search for firewire devices
	CFDictionaryRef matchDict = IOServiceMatching("IOFireWireDevice");
	CFRetain(matchDict);
	
	// register notifications
	IOServiceAddMatchingNotification(m_notificationPort, kIOMatchedNotification,
									 matchDict, cDevAdded, (void *) self,
									 &m_addedIterator);
	IOServiceAddMatchingNotification(m_notificationPort, kIOTerminatedNotification,
									 matchDict, cDevRemoved, (void *) self,
									 &m_removedIterator);
	
	// Prime notifications
	[self devAdded: m_addedIterator];
	[self devRemoved: m_removedIterator];
}

- (void) unregisterCallback {
	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), m_runLoopSource, kCFRunLoopDefaultMode);
	IONotificationPortDestroy(m_notificationPort);
	
	IOObjectRelease(m_addedIterator);
	IOObjectRelease(m_removedIterator);
}

- (void) checkData {
	io_iterator_t iterator = 0;
	
	// Create matching dictionary for I/O Kit enumeration
	CFMutableDictionaryRef matchDict = IOServiceMatching("IOFireWireDevice");
	kern_return_t kr = IOServiceGetMatchingServices(kIOMasterPortDefault, matchDict, &iterator);
	ZAssert(kr == KERN_SUCCESS, @"IOServiceGetMatchingServices returned 0x%08x", kr);
	
	// Get all devices
	m_devices = [[NSDictionary new] autorelease];
	[self devAdded: iterator];
	IOObjectRelease(iterator);
}

#pragma mark - Internal callbacks

- (void) devAdded: (io_iterator_t) iterator {
	NSMutableDictionary *devices = [[NSMutableDictionary new] autorelease];
	io_service_t device;
	
	while ((device = IOIteratorNext(iterator))) {
		// Get device details
		NSNumber *guid = [self guidForDevice: &device];
		ZAssert(guid, @"FireWire >> failed getting GUID.");
		
		// Try to get device name
		NSString *name = [self nameForDevice: &device];
		if (!name)
			name = NSLocalizedString(@"(Unnamed device)", @"FireWireSource");
		
		// Lookup vendor name
		NSString *vendor = [self vendorForDevice: &device];
		if (!vendor)
			vendor = @"?";
		
		IOObjectRelease(device);
		NSDictionary *dev = [NSDictionary dictionaryWithObjectsAndKeys:
							 guid, @"guid",
							 name, @"name",
							 vendor, @"vendor",
							 nil];
		
		// Add to list
		[devices setObject: dev forKey: guid];
	}
	
	// store when different
	if (![self.devices isEqualToDictionary: devices])
		self.devices = [[devices copy] autorelease];
}

- (void) devRemoved: (io_iterator_t) iterator {
	io_service_t device;
	
	while ((device = IOIteratorNext(iterator)))
		IOObjectRelease(device);
	
	[self checkData];
}

static void cDevAdded(void *ref, io_iterator_t iterator) {
	[(FireWireSource *) ref devAdded:iterator];
}

static void cDevRemoved(void *ref, io_iterator_t iterator) {
	[(FireWireSource *) ref devRemoved:iterator];
}

#pragma mark - Utility methods

- (NSNumber *) guidForDevice: (io_service_t *) device {
	NSNumber *guid = (NSNumber *) IORegistryEntryCreateCFProperty(*device, CFSTR("GUID"),
																  kCFAllocatorDefault, 0);
	
	return [guid autorelease];
}

- (NSString *) nameForDevice: (io_service_t *) device {
	NSString *name = (NSString *) IORegistryEntryCreateCFProperty(*device, CFSTR("FireWire Product Name"),
																  kCFAllocatorDefault, 0);
	
	return [name autorelease];
}

- (NSString *) vendorForDevice: (io_service_t *) device {
	NSString *name = (NSString *) IORegistryEntryCreateCFProperty(*device, CFSTR("FireWire Vendor Name"),
																  kCFAllocatorDefault, 0);
	
	return [name autorelease];
}

@end
