//
//	WLANSSIDRule.m
//	ControlPlane
//
//	Created by David Jennes on 24/09/11.
//	Copyright 2011. All rights reserved.
//

#import "WLANSource.h"
#import "WLANSSIDRule.h"

@implementation WLANSSIDRule

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_ssid = nil;
	
	return self;
}

#pragma mark - Source observe functions

- (void) networksChangedWithOld: (NSArray *) oldList andNew: (NSArray *) newList {
	BOOL found = NO;
	
	// loop through services
	for (NSDictionary *item in newList) {
		found = [m_ssid isEqualToString: [item valueForKey: @"SSID"]];
		
		if (found)
			break;
	}
	
	self.match = found;
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"Wi-Fi SSID", @"Rule type");
}

- (NSString *) category {
	return NSLocalizedString(@"Network", @"Rule category");
}

- (NSString *) helpText {
	return NSLocalizedString(@"Connected to a WiFi network named", @"WLANBSSIDRule");
}

- (void) beingEnabled {
	Source *source = [SourcesManager.sharedSourcesManager registerRule: self toSource: @"WLANSource"];
	
	// currently a match?
	[self networksChangedWithOld: nil andNew: ((WLANSource *) source).networks];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unregisterRule: self fromSource: @"WLANSource"];
}

- (void) loadData: (id) data {
	m_ssid = data;
}

- (NSString *) describeValue: (id) value {
	return value;
}

- (NSArray *) suggestedValues {
	WLANSource *source = (WLANSource *) [SourcesManager.sharedSourcesManager getSource: @"WLANSource"];
	NSMutableArray *result = [NSMutableArray new];
	
	// loop through networks
	for (NSDictionary *item in source.networks)
		[result addObject: [item valueForKey: @"SSID"]];
	
	return result;
}

@end
