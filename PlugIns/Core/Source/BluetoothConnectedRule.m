//
//  BluetoothConnectedRule.m
//  ControlPlane
//
//  Created by David Jennes on 16/10/11.
//  Copyright (c) 2011. All rights reserved.
//

#import "BluetoothConnectedRule.h"
#import "BluetoothConnectedSource.h"

@implementation BluetoothConnectedRule

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_address = nil;
	
	return self;
}

#pragma mark - Source observe functions

- (void) devicesChangedWithOld: (NSDictionary *) oldList andNew: (NSDictionary *) newList {
	self.match = ([newList objectForKey: m_address] != nil);
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"Bluetooth (Connected)", @"Rule type");
}

- (NSString *) category {
	return NSLocalizedString(@"Devices", @"Rule category");
}

- (void) beingEnabled {
	Source *source = [SourcesManager.sharedSourcesManager registerRule: self toSource: @"BluetoothConnectedSource"];
	
	// currently a match?
	[self devicesChangedWithOld: nil andNew: ((BluetoothConnectedSource *) source).devices];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unregisterRule: self fromSource: @"AudioSource"];
}

- (void) loadData: (id) data {
	m_address = data;
}

- (NSString *) describeValue: (id) value {
	BluetoothConnectedSource *source = (BluetoothConnectedSource *) [SourcesManager.sharedSourcesManager getSource: @"BluetoothConnectedSource"];
	
	// get device data
	NSDictionary *data = [source.devices objectForKey: value];
	if (!data)
		data = [source.recentDevices objectForKey: value];
	if (!data)
		return NSLocalizedString(@"Unknown Device", @"BluetoothConnectedRule value description");
	
	// describe it
	return [NSString stringWithFormat: @"%@ [%@]",
			[data objectForKey: @"name"],
			[data objectForKey: @"vendor"]];
}

- (NSArray *) suggestedValues {
	BluetoothConnectedSource *source = (BluetoothConnectedSource *) [SourcesManager.sharedSourcesManager getSource: @"BluetoothConnectedSource"];
	
	return source.recentDevices.allKeys;
}

@end
