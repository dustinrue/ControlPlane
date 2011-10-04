//
//	USBRule.m
//	ControlPlane
//
//	Created by David Jennes on 30/09/11.
//	Copyright 2011. All rights reserved.
//

#import "USBRule.h"
#import "USBSource.h"

@implementation USBRule

registerRuleType(USBRule)

#pragma mark - Source observe functions

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_product = nil;
	m_vendor = nil;
	
	return self;
}

- (void) devicesChangedWithOld: (NSArray *) oldList andNew: (NSArray *) newList {
	BOOL found = NO;
	
	// loop through devices
	for (NSDictionary *device in newList) {
		found = [m_product isEqualToNumber: [device valueForKey: @"productID"]] &&
			[m_vendor isEqualToNumber: [device valueForKey: @"vendorID"]];
		
		if (found)
			break;
	}
	
	self.match = found;
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"USB", @"Rule type");
}

- (NSString *) category {
	return NSLocalizedString(@"Devices", @"Rule category");
}

- (void) beingEnabled {
	Source *source = [SourcesManager.sharedSourcesManager registerRule: self toSource: @"USBSource"];
	
	// currently a match?
	[self devicesChangedWithOld: nil andNew: ((USBSource *) source).devices];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unRegisterRule: self fromSource: @"USBSource"];
}

- (void) loadData: (id) data {
	m_product = [data objectForKey: @"productID"];
	m_vendor = [data objectForKey: @"vendorID"];
}

- (NSString *) describeValue: (id) value {
	return [NSString stringWithFormat: @"%@ (%@)",
			[value valueForKey: @"name"],
			[value valueForKey: @"vendor"]];
}

- (NSArray *) suggestedValues {
	USBSource *source = (USBSource *) [SourcesManager.sharedSourcesManager getSource: @"USBSource"];
	
	return source.devices;
}

@end
