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

registerRuleType(WLANSSIDRule)

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

- (void) beingEnabled {
	Source *source = [SourcesManager.sharedSourcesManager registerRule: self toSource: @"WLANSource"];
	
	// currently a match?
	[self networksChangedWithOld: nil andNew: ((WLANSource *) source).networks];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unRegisterRule: self fromSource: @"WLANSource"];
}

- (void) loadData {
	m_ssid = [self.data objectForKey: @"parameter"];
}

- (NSArray *) suggestedValues {
	WLANSource *source = (WLANSource *) [SourcesManager.sharedSourcesManager getSource: @"WLANSource"];
	NSMutableArray *result = [[NSArray new] autorelease];
	
	// loop through networks
	for (NSDictionary *item in source.networks) {
		[result addObject: [NSDictionary dictionaryWithObjectsAndKeys:
							[item valueForKey: @"SSID"], @"parameter",
							[item valueForKey: @"SSID"], @"description", nil]];
	}
	
	return result;
}

@end
