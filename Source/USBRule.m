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

- (void) loadData {
	m_product = [self.data valueForKeyPath: @"parameter.productID"];
	m_vendor = [self.data valueForKeyPath: @"parameter.vendorID"];
}

- (NSArray *) suggestedValues {
	USBSource *source = (USBSource *) [SourcesManager.sharedSourcesManager getSource: @"USBSource"];
	NSMutableArray *result = [[NSArray new] autorelease];
	
	// loop through apps
	for (NSDictionary *device in source.devices) {
		NSString *description = [NSString stringWithFormat: @"%@ (%@)",
								 [device valueForKey: @"name"],
								 [device valueForKey: @"vendor"]];
		
		[result addObject: [NSDictionary dictionaryWithObjectsAndKeys:
							device, @"parameter",
							description, @"description", nil]];
	}
	
	return result;
}

@end
