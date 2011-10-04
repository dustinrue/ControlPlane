//
//  NetworkLinkRule.m
//  ControlPlane
//
//  Created by David Jennes on 04/10/11.
//  Copyright 2011. All rights reserved.
//

#import "NetworkLinkRule.h"
#import "NetworkLinkSource.h"

@implementation NetworkLinkRule

registerRuleType(NetworkLinkRule)

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
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

- (void) beingEnabled {
	Source *source = [SourcesManager.sharedSourcesManager registerRule: self toSource: @"NetworkLinkSource"];
	
	// currently a match?
	[self interfacesChangedWithOld: nil andNew: ((NetworkLinkSource *) source).interfaces];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unRegisterRule: self fromSource: @"NetworkLinkSource"];
}

- (void) loadData {
	m_name = [self.data valueForKeyPath: @"parameter.name"];
	m_active = [[self.data valueForKeyPath: @"parameter.active"] boolValue];
}

- (NSArray *) suggestedValues {
	NetworkLinkSource *source = (NetworkLinkSource *) [SourcesManager.sharedSourcesManager getSource: @"NetworkLinkSource"];
	NSMutableArray *result = [[NSArray new] autorelease];
	NSString *description = nil;
	
	// loop through devices
	for (NSString *interface in source.interfaces)
		// active & inactive
		for (int i = 0; i < 2; ++i) {
			BOOL active = (i == 1);
			
			if (active)
				description = [NSString stringWithFormat:
							   NSLocalizedString(@"%@ (%@) link active", @"NetworkLinkRule suggestion description"),
							   interface, [source.interfaceNames objectForKey: interface]];
			else
				description = [NSString stringWithFormat:
							   NSLocalizedString(@"%@ (%@) link inactive", @"NetworkLinkRule suggestion description"),
							   interface, [source.interfaceNames objectForKey: interface]];
			
			[result addObject: [NSDictionary dictionaryWithObjectsAndKeys:
								[NSDictionary dictionaryWithObjectsAndKeys:
								 interface, @"name",
								 [NSNumber numberWithBool: active], @"active",
								 nil], @"parameter",
								description, @"description",
								nil]];
	}
	
	return result;
}

@end
