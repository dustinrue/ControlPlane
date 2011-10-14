//
//  BluetoothSource.m
//  ControlPlane
//
//  Created by David Jennes on 08/10/11.
//  Copyright 2011. All rights reserved.
//

#import "BluetoothSource.h"

@implementation BluetoothSource

@synthesize connectedDevices = m_connectedDevices;
@synthesize devices = m_devices;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	self.connectedDevices = [NSDictionary new];
	self.devices = [NSDictionary new];
	
	return self;
}

#pragma mark - Required implementation of 'CallbackSource' class

- (NSArray *) observableKeys {
	return [NSArray arrayWithObjects: @"connectedDevices", @"devices", nil];
}

- (void) registerCallback {
	
}

- (void) unregisterCallback {
	
}

- (void) checkData {
	
	// store it
}

#pragma mark - Internal callbacks



@end
