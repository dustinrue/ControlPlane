//
//  IPRule.m
//  ControlPlane
//
//  Created by David Jennes on 04/10/11.
//  Copyright 2011. All rights reserved.
//

#import "IPRule.h"
#import "NetworkSource.h"

@implementation IPRule

registerRuleType(IPRule)

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_ip.value = 0;
	m_mask.value = 0;
	
	return self;
}

#pragma mark - Source observe functions

- (Address) stringToAddress: (NSString *) str {
	NSArray *octets = [str componentsSeparatedByString: @"."];
	Address result;
	
	for (NSUInteger i = 0; i < 4; ++i)
		result.octets[i] = [[octets objectAtIndex: i] intValue];
	
	return result;
}

- (void) addressesChangedWithOld: (NSArray *) oldList andNew: (NSArray *) newList {
	BOOL match = NO;
	
	for (NSString *item in newList) {
		Address address = [self stringToAddress: item];
		match = ((address.value & m_mask.value) == (m_ip.value & m_mask.value));
		
		// stop if we found a match
		if (match)
			break;
	}
	
	self.match = match;
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"IP Address", @"Rule type");
}

- (NSString *) category {
	return NSLocalizedString(@"Network", @"Rule category");
}

- (void) beingEnabled {
	Source *source = [SourcesManager.sharedSourcesManager registerRule: self toSource: @"NetworkSource"];
	
	// currently a match?
	[self addressesChangedWithOld: nil andNew: ((NetworkSource *) source).addresses];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unRegisterRule: self fromSource: @"NetworkSource"];
}

- (void) loadData: (id) data {
	m_ip = [self stringToAddress: [data objectForKey: @"ip"]];
	m_mask = [self stringToAddress: [data objectForKey: @"netmask"]];
}

- (NSString *) describeValue: (id) value {
	return [NSString stringWithFormat:
			NSLocalizedString(@"Match %@ in subnet %@", @"IPRule value description"),
			[value objectForKey: @"ip"],
			[value objectForKey: @"netmask"]];
}

- (NSArray *) suggestedValues {
	NetworkSource *source = (NetworkSource *) [SourcesManager.sharedSourcesManager getSource: @"NetworkSource"];
	NSString *address = nil;
	
	// do we have an ip?
	if (source.addresses.count > 0)
		address = [source.addresses objectAtIndex: 0];
	else
		address = @"192.168.0.1";
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
			address, @"ip",
			@"255.255.255.0", @"netmask",
			nil];
}

@end
