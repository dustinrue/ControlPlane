//
//	BonjourRule.m
//	ControlPlane
//
//	Created by David Jennes on 24/09/11.
//	Copyright 2011. All rights reserved.
//

#import "BonjourRule.h"
#import "BonjourSource.h"

@implementation BonjourRule

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	if (!self) return nil;
	
	m_host = nil;
	m_service = nil;
	
	return self;
}

#pragma mark - Source observe functions

- (void) servicesChangedWithOld: (NSArray *) oldList andNew: (NSArray *) newList {
	BOOL found = NO;
	
	// loop through services
	for (NSDictionary *item in newList) {
		found = [m_host isEqualToString: [item valueForKey: @"host"]] &&
				[m_service isEqualToString: [item valueForKey: @"service"]];
		
		if (found)
			break;
	}
	
	self.match = found;
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"Bonjour", @"Rule type");
}

- (NSString *) category {
	return NSLocalizedString(@"Network", @"Rule category");
}

- (NSString *) helpText {
	return NSLocalizedString(@"In presence of", @"BonjourRule");
}

- (NSArray *) observedSources {
	return [NSArray arrayWithObject: BonjourSource.class];
}

- (void) loadData: (id) data {
	m_host = [data objectForKey: @"host"];
	m_service = [data objectForKey: @"service"];
}

- (NSString *) describeValue: (id) value {
	return [NSString stringWithFormat:
			NSLocalizedString(@"%@ on %@", @"BonjourRule value desciption"),
			[value valueForKey: @"host"],
			[value valueForKey: @"service"]];
}

- (NSArray *) suggestedValues {
	BonjourSource *source = (BonjourSource *) [SourcesManager.sharedSourcesManager getSource: BonjourSource.class];
	
	return source.services;
}

@end
