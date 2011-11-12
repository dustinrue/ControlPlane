//
//  BluetoothScanRule.m
//  ControlPlane
//
//  Created by David Jennes on 16/10/11.
//  Copyright (c) 2011. All rights reserved.
//

#import "BluetoothScannerRule.h"
#import "BluetoothScannerSource.h"

@implementation BluetoothScannerRule

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	if (!self) return nil;
	
	m_address = nil;
	
	return self;
}

#pragma mark - Source observe functions

- (void) devicesChangedWithOld: (NSDictionary *) oldList andNew: (NSDictionary *) newList {
	self.match = ([newList objectForKey: m_address] != nil);
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"Bluetooth (Scan)", @"Rule type");
}

- (NSString *) category {
	return NSLocalizedString(@"Devices", @"Rule category");
}

- (NSString *) helpText {
	return NSLocalizedString(@"In presence of", @"BluetoothScannerRule");
}

- (void) beingEnabled {
	Source *source = [SourcesManager.sharedSourcesManager registerRule: self toSource: @"BluetoothScannerSource"];
	
	// currently a match?
	[self devicesChangedWithOld: nil andNew: ((BluetoothScannerSource *) source).devices];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unregisterRule: self fromSource: @"AudioSource"];
}

- (void) loadData: (id) data {
	m_address = data;
}

- (NSString *) describeValue: (id) value {
	BluetoothScannerSource *source = (BluetoothScannerSource *) [SourcesManager.sharedSourcesManager getSource: @"BluetoothScannerSource"];
	
	// get device data
	NSDictionary *data = [source.devices objectForKey: value];
	if (!data)
		return NSLocalizedString(@"Unknown Device", @"BluetoothScannerRule value description");
	
	// describe it
	return [NSString stringWithFormat: @"%@ [%@]",
			[data objectForKey: @"name"],
			[data objectForKey: @"vendor"]];
}

- (NSArray *) suggestedValues {
	BluetoothScannerSource *source = (BluetoothScannerSource *) [SourcesManager.sharedSourcesManager getSource: @"BluetoothScannerSource"];
	
	return source.devices.allKeys;
}

@end
