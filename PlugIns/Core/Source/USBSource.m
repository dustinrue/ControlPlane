//
//  USBSource.m
//  ControlPlane
//
//  Created by David Jennes on 30/09/11.
//  Copyright 2011. All rights reserved.
//

#import "DB.h"
#import "USBSource.h"
#import <IOKit/usb/IOUSBLib.h>

static void cDevAdded(void *ref, io_iterator_t iterator);
static void cDevRemoved(void *ref, io_iterator_t iterator);

@interface USBSource (Private)

- (void) devAdded: (io_iterator_t) iterator;
- (void) devRemoved: (io_iterator_t) iterator;
- (NSNumber *) productIdForDevice: (io_service_t *) device;
- (NSNumber *) vendorIdForDevice: (io_service_t *) device;
- (NSString *) nameForDevice: (io_service_t *) device;
- (NSString *) vendorForDevice: (NSNumber *) vendorID;
- (BOOL) isInternalDevice: (NSNumber *) product vendor: (NSNumber *) vendor;

@end

@implementation USBSource

@synthesize devices = m_devices;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	self.devices = [NSArray new];
	
	return self;
}

#pragma mark - Required implementation of 'CallbackSource' class

- (NSArray *) observableKeys {
	return [NSArray arrayWithObject: @"devices"];
}

- (void) registerCallback {
	m_notificationPort = IONotificationPortCreate(kIOMasterPortDefault);
	m_runLoopSource = IONotificationPortGetRunLoopSource(m_notificationPort);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), m_runLoopSource, kCFRunLoopDefaultMode);
	
	// Only search for USB devices
	CFDictionaryRef matchDict = IOServiceMatching(kIOUSBDeviceClassName);
	CFRetain(matchDict);
	
	// register notifications
	IOServiceAddMatchingNotification(m_notificationPort, kIOMatchedNotification,
									 matchDict, cDevAdded, (__bridge void *) self,
									 &m_addedIterator);
	IOServiceAddMatchingNotification(m_notificationPort, kIOTerminatedNotification,
									 matchDict, cDevRemoved, (__bridge void *) self,
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
	CFMutableDictionaryRef matchDict = IOServiceMatching(kIOUSBDeviceClassName);
	kern_return_t kr = IOServiceGetMatchingServices(kIOMasterPortDefault, matchDict, &iterator);
	ZAssert(kr == KERN_SUCCESS, @"IOServiceGetMatchingServices returned 0x%08x", kr);
	
	// Get all devices
	m_devices = [NSArray new];
	[self devAdded: iterator];
	IOObjectRelease(iterator);
}

#pragma mark - Internal callbacks

- (void) devAdded: (io_iterator_t) iterator {
	NSMutableArray *devices = [NSMutableArray new];
	io_service_t device;
	
	while ((device = IOIteratorNext(iterator))) {
		// Get device details
		NSNumber *productID = [self productIdForDevice: &device];
		ZAssert(productID, @"USB >> failed getting product ID.");
		NSNumber *vendorID = [self vendorIdForDevice: &device];
		ZAssert(vendorID, @"USB >> failed getting vendor ID.");
		
		// don't store internal devices
		if ([self isInternalDevice: productID vendor: vendorID])
			continue;
		
		// Try to get device name
		NSString *name = [self nameForDevice: &device];
		ZAssert(name, @"USB >> failed getting device name.");
		
		// Lookup vendor name
		NSString *vendor = [self vendorForDevice: vendorID];
		IOObjectRelease(device);
		
		// create device info
		NSDictionary *dev = [NSDictionary dictionaryWithObjectsAndKeys:
							 productID, @"productID",
							 vendorID, @"vendorID",
							 name, @"name",
							 vendor, @"vendor",
							 nil];
		
		// Add to list
		[devices addObject: dev];
	}
	
	// store when different
	if (![self.devices isEqualTo: devices])
		self.devices = [devices copy];
}

- (void) devRemoved: (io_iterator_t) iterator {
	io_service_t device;
	
	while ((device = IOIteratorNext(iterator)))
		IOObjectRelease(device);
	
	[self checkData];
}

static void cDevAdded(void *ref, io_iterator_t iterator) {
	[(__bridge USBSource *) ref devAdded: iterator];
}

static void cDevRemoved(void *ref, io_iterator_t iterator) {
	[(__bridge USBSource *) ref devRemoved: iterator];
}

#pragma mark - Utility methods

- (NSNumber *) productIdForDevice: (io_service_t *) device {
	CFMutableDictionaryRef props = nil;
	NSNumber *result = nil;
	
	kern_return_t kr = IORegistryEntryCreateCFProperties(*device, &props, kCFAllocatorDefault, kNilOptions);
	ZAssert(kr == kIOReturnSuccess, @"Unable to get USB device ID");
	
	result = (__bridge NSNumber *)(CFDictionaryGetValue(props, CFSTR("idProduct")));
	CFRelease(props);
	
	return result;
}

- (NSNumber *) vendorIdForDevice: (io_service_t *) device {
	CFMutableDictionaryRef props = nil;
	NSNumber *result = nil;
	
	kern_return_t kr = IORegistryEntryCreateCFProperties(*device, &props, kCFAllocatorDefault, kNilOptions);
	ZAssert(kr == kIOReturnSuccess, @"Unable to get USB vendor ID");
	
	result = (__bridge NSNumber *)(CFDictionaryGetValue(props, CFSTR("idVendor")));
	CFRelease(props);
	
	return result;
}

- (NSString *) nameForDevice: (io_service_t *) device {
	io_name_t name;
	kern_return_t kr = IORegistryEntryGetName(*device, name);
	ZAssert(kr == KERN_SUCCESS, @"IORegistryEntryGetName failed: 0x%08x", kr);
	
	return [NSString stringWithUTF8String: name];
}

- (NSString *) vendorForDevice: (NSNumber *) vendorID {
	NSDictionary *vendors = DB.sharedDB.usbVendorDB;
	NSString *vendor = [NSString stringWithFormat: @"%d", vendorID];
	NSString *name = [vendors valueForKey: vendor];
	
	if (name)
		return name;
	
	return [NSString stringWithFormat: @"0x%04X", vendorID];
}

- (BOOL) isInternalDevice: (NSNumber *) product vendor: (NSNumber *) vendor {
	static const struct {
		UInt16 vendor, product;
	} devices[] = {
		{0x05AC, 0x0217},		// (Apple) Internal Keyboard/Trackpad
		{0x05AC, 0x021A},		// (Apple) Apple Internal Keyboard/Trackpad
		{0x05AC, 0x1003},		// (Apple) Hub in Apple Extended USB Keyboard
		{0x05AC, 0x8005},		// (Apple) UHCI Root Hub Simulation
		{0x05AC, 0x8006},		// (Apple) EHCI Root Hub Simulation
		{0x05AC, 0x8205},		// (Apple) IOUSBWirelessControllerDevice
		{0x05AC, 0x8206},		// (Apple) IOUSBWirelessControllerDevice
		{0x05AC, 0x8240},		// (Apple) IR Receiver
		{0x05AC, 0x8501},		// (Apple) Built-in iSight
	};
	
	unsigned size = sizeof(devices) / sizeof(devices[0]);
	BOOL found = NO;
	
	for (unsigned i = 0; i < size && !found; ++i)
		found = devices[i].vendor == vendor.intValue && devices[i].product == product.intValue;
	
	return found;
}

@end
