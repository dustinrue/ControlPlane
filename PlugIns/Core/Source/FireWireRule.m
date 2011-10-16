//
//  FireWireRule.m
//  ControlPlane
//
//  Created by David Jennes on 29/09/11.
//  Copyright 2011. All rights reserved.
//

#import "FireWireRule.h"
#import "FireWireSource.h"

@implementation FireWireRule

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_guid = nil;
	
	return self;
}

#pragma mark - Source observe functions

- (void) devicesChangedWithOld: (NSDictionary *) oldList andNew: (NSDictionary *) newList {
	self.match = ([newList objectForKey: m_guid] != nil);
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"FireWire", @"Rule type");
}

- (NSString *) category {
	return NSLocalizedString(@"Devices", @"Rule category");
}

- (NSString *) helpText {
	return NSLocalizedString(@"Connected to", @"FireWireRule");
}

- (void) beingEnabled {
	Source *source = [SourcesManager.sharedSourcesManager registerRule: self toSource: @"FireWireSource"];
	
	// currently a match?
	[self devicesChangedWithOld: nil andNew: ((FireWireSource *) source).devices];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unregisterRule: self fromSource: @"FireWireSource"];
}

- (void) loadData: (id) data {
	m_guid = data;
}

- (NSString *) describeValue: (id) value {
	FireWireSource *source = (FireWireSource *) [SourcesManager.sharedSourcesManager getSource: @"FireWireSource"];
	NSDictionary *item = [source.devices objectForKey: value];
	
	if (item)
		return [NSString stringWithFormat: @"%@ (%@)",
				[item valueForKey: @"name"],
				[item valueForKey: @"vendor"]];
	else
		return NSLocalizedString(@"Unknown Device", @"FireWireRule value description");
}

- (NSArray *) suggestedValues {
	FireWireSource *source = (FireWireSource *) [SourcesManager.sharedSourcesManager getSource: @"FireWireSource"];
	
	return source.devices.allKeys;
}

@end
