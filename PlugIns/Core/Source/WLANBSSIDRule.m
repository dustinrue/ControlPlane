//
//	WLANBSSIDRule.m
//	ControlPlane
//
//	Created by David Jennes on 24/09/11.
//	Copyright 2011. All rights reserved.
//

#import "WLANBSSIDRule.h"
#import "WLANSource.h"

@implementation WLANBSSIDRule

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	if (!self) return nil;
	
	m_bssid = nil;
	
	return self;
}

#pragma mark - Source observe functions

- (void) networksChangedWithOld: (NSArray *) oldList andNew: (NSArray *) newList {
	BOOL found = NO;
	
	// loop through services
	for (NSDictionary *item in newList) {
		found = [m_bssid isEqualToString: [item valueForKey: @"BSSID"]];
		
		if (found)
			break;
	}
	
	self.match = found;
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"Wi-Fi BSSID", @"Rule type");
}

- (NSString *) category {
	return NSLocalizedString(@"Network", @"Rule category");
}

- (NSString *) helpText {
	return NSLocalizedString(@"Connected to an access point with MAC address", @"WLANBSSIDRule");
}

- (void) beingEnabled {
	[SourcesManager.sharedSourcesManager registerRule: self toSource: @"WLANSource"];
	
	// currently a match?
	WLANSource *source = (WLANSource *) [SourcesManager.sharedSourcesManager getSource: @"WLANSource"];
	[self networksChangedWithOld: nil andNew: source.networks];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unregisterRule: self fromSource: @"WLANSource"];
}

- (void) loadData: (id) data {
	m_bssid = [data objectForKey: @"BSSID"];
}

- (NSString *) describeValue: (id) value {
	return [NSString stringWithFormat: @"%@ (%@)",
			[value valueForKey: @"BSSID"],
			[value valueForKey: @"SSID"]];
}

- (NSArray *) suggestedValues {
	WLANSource *source = (WLANSource *) [SourcesManager.sharedSourcesManager getSource: @"WLANSource"];
	
	return source.networks;
}

@end
