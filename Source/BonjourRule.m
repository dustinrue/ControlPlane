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

registerRuleType(BonjourRule)

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
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

- (void) beingEnabled {
	Source *source = [SourcesManager.sharedSourcesManager registerRule: self toSource: @"BonjourSource"];
	
	// currently a match?
	[self servicesChangedWithOld: nil andNew: ((BonjourSource *) source).services];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unRegisterRule: self fromSource: @"BonjourSource"];
}

- (void) loadData {
	m_host = [[self.data objectForKey: @"parameter"] objectForKey: @"host"];
	m_service = [[self.data objectForKey: @"parameter"] objectForKey: @"service"];
}

- (NSArray *) suggestedValues {
	BonjourSource *source = (BonjourSource *) [SourcesManager.sharedSourcesManager getSource: @"BonjourSource"];
	NSMutableArray *result = [[NSArray new] autorelease];
	
	// loop through services
	for (NSDictionary *item in source.services) {
		NSString *description = [NSString stringWithFormat:
								 NSLocalizedString(@"%@ on %@", @"BonjourRule suggestion desciption"),
								 [item valueForKey: @"host"],
								 [item valueForKey: @"service"]];
		
		[result addObject: [NSDictionary dictionaryWithObjectsAndKeys:
							item, @"parameter",
							description, @"description", nil]];
	}
	
	return result;
}

@end
