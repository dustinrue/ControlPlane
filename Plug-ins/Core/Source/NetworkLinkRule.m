//
//  NetworkLinkRule.m
//  ControlPlane
//
//  Created by David Jennes on 04/10/11.
//  Copyright 2011. All rights reserved.
//

#import "NetworkLinkRule.h"
#import "NetworkSource.h"

@implementation NetworkLinkRule

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	if (!self) return nil;
	
	m_name = nil;
	m_active = YES;
	
	return self;
}

#pragma mark - Source observe functions

- (void) interfacesChangedWithOld: (NSDictionary *) oldList andNew: (NSDictionary *) newList {
	self.match = ([[newList objectForKey: m_name] boolValue] == m_active);
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"Link", @"Rule type");
}

- (NSString *) category {
	return NSLocalizedString(@"Network", @"Rule category");
}

- (NSString *) helpText {
	return NSLocalizedString(@"Network link on interface", @"NetworkLinkRule");
}

- (NSArray *) observedSources {
	return [NSArray arrayWithObject: NetworkSource.class];
}

- (void) loadData: (id) data {
	m_name = [data objectForKey: @"name"];
	m_active = [[data objectForKey: @"active"] boolValue];
}

- (NSString *) describeValue: (id) value {
	NetworkSource *source = (NetworkSource *) [SourcesManager.sharedSourcesManager getSource: NetworkSource.class];
	NSString *interface = [value objectForKey: @"name"];
	
	// get interface name
	NSString *name = [source.interfaceNames objectForKey: interface];
	if (!name)
		name = NSLocalizedString(@"Unknown Interface", @"NetworkLinkRule value description");
	
	if ([[value objectForKey: @"active"] boolValue])
		return [NSString stringWithFormat:
				NSLocalizedString(@"%@ (%@) link active", @"NetworkLinkRule value description"),
				interface, name];
	else
		return [NSString stringWithFormat:
				NSLocalizedString(@"%@ (%@) link active", @"NetworkLinkRule value description"),
				interface, name];
}

- (NSArray *) suggestedValues {
	NetworkSource *source = (NetworkSource *) [SourcesManager.sharedSourcesManager getSource: NetworkSource.class];
	NSMutableArray *result = [NSMutableArray new];
	
	// loop through devices
	for (NSString *interface in source.interfaces)
		// active & inactive
		for (int i = 0; i < 2; ++i) {
			BOOL active = (i == 1);
			
			[result addObject: [NSDictionary dictionaryWithObjectsAndKeys:
								interface, @"name",
								[NSNumber numberWithBool: active], @"active",
								nil]];
	}
	
	return result;
}

@end
