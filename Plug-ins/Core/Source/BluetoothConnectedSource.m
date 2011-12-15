//
//  BluetoothSource.m
//  ControlPlane
//
//  Created by David Jennes on 08/10/11.
//  Copyright 2011. All rights reserved.
//

#import "BluetoothConnectedSource.h"
#import "DB.h"
#import <IOBluetooth/objc/IOBluetoothDevice.h>

@interface BluetoothConnectedSource (Private)

- (void) deviceConnected: (IOBluetoothUserNotification *) notification device: (IOBluetoothDevice *) device;
- (void) deviceDisconnected: (IOBluetoothUserNotification *) notification device: (IOBluetoothDevice *) device;
- (NSDictionary *) deviceToDictionary: (IOBluetoothDevice *) device;
- (NSString *) vendorByMAC: (NSString *) address;

@end

@implementation BluetoothConnectedSource

@synthesize devices = m_devices;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	if (!self) return nil;
	
	self.devices = [NSDictionary new];
	m_notifications = nil;
	m_disconnectNotifications = nil;
	
	return self;
}

- (NSDictionary *) recentDevices {
	NSMutableDictionary *devices = [NSMutableDictionary new];
	
	// get favourites
	for (IOBluetoothDevice *device in IOBluetoothDevice.favoriteDevices)
		[devices setObject: [self deviceToDictionary: device] forKey: [device getAddressString]];
	
	// get recents
	for (IOBluetoothDevice *device in [IOBluetoothDevice recentDevices: 10])
		if (![devices objectForKey: [device getAddressString]])
			[devices setObject: [self deviceToDictionary: device] forKey: [device getAddressString]];
	
	return devices;
}

#pragma mark - Required implementation of 'CallbackSource' class

- (NSArray *) observableKeys {
	return [NSArray arrayWithObject: @"devices"];
}

- (void) registerCallback {
	m_notifications = [IOBluetoothDevice registerForConnectNotifications: self
																selector: @selector(deviceConnected:device:)];
	
	m_disconnectNotifications = [NSMutableArray new];
}

- (void) unregisterCallback {
	[m_notifications unregister];
	m_notifications = nil;
	
	// we don't care about disconnection events anymore
	for (IOBluetoothUserNotification *notification in m_disconnectNotifications)
		[notification unregister];
}

- (void) checkData {
	NSMutableDictionary *devices = [NSMutableDictionary new];
	IOBluetoothUserNotification *notification = nil;
	
	// get connected devices from recent list
	for (IOBluetoothDevice *device in [IOBluetoothDevice recentDevices: 20])
		if (device.isConnected && ![devices objectForKey: [device getAddressString]]) {
			[devices setObject: [self deviceToDictionary: device] forKey: [device getAddressString]];
			
			// we want to know when the device disconnects
			notification = [device registerForDisconnectNotification: self
															selector: @selector(deviceDisconnected:device:)];
			[m_disconnectNotifications addObject: notification];
		}
	
	// store it
	if (![devices isEqualToDictionary: self.devices])
		self.devices = devices;
}

#pragma mark - Internal callbacks

- (void) deviceConnected: (IOBluetoothUserNotification *) notification device: (IOBluetoothDevice *) device {
	LogInfo_Source(@"Got notified of '%@' connecting!", device.name);
	NSString *address = [device getAddressString];
	IOBluetoothUserNotification *disconnect = nil;
    
    // register for device disconnection
	disconnect = [device registerForDisconnectNotification: self
												  selector: @selector(deviceDisconnected:device:)];
	[m_disconnectNotifications addObject: disconnect];
    
    // add device to connected list
	NSMutableDictionary *devices = [self.devices mutableCopy];
	ZAssert(![devices objectForKey: address], @"Connected already known device");
	[devices setObject: [self deviceToDictionary: device] forKey: address];
	
	// store it
	self.devices = devices;
}

- (void) deviceDisconnected: (IOBluetoothUserNotification *) notification device: (IOBluetoothDevice *) device {
	LogInfo_Source(@"Got notified of '%@' disconnecting!", device.name);
	NSString *address = [device getAddressString];
    
	// remove notification from disconnect list
	[m_disconnectNotifications removeObject: notification];
	
	// remove device from connected list
	NSMutableDictionary *devices = [self.devices mutableCopy];
	ZAssert([devices objectForKey: address], @"Disconnected unknown device");
	[devices removeObjectForKey: address];
	
	// store it
	self.devices = devices;
}

#pragma mark - Utility methods

- (NSDictionary *) deviceToDictionary: (IOBluetoothDevice *) device {
	NSString *name = device.name;
	
	if (!name)
		name = NSLocalizedString(@"(Unnamed Device)", @"BluetoothSource");
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
			device.name, @"name",
			[self vendorByMAC: [device getAddressString]], @"address",
			nil];
}

- (NSString *) vendorByMAC: (NSString *) address {
	NSDictionary *ouiDb = DB.sharedDB.ouiDB;
	NSString *oui = [address substringToIndex: 8].uppercaseString;
	
	NSString *name = [ouiDb valueForKey:oui];
	if (!name)
		name = @"Unknown";
	LogVerbose_Source(@"Converted %@ to %@", oui, name);
	
	return name;
}

@end
