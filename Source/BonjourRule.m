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

#pragma mark - Source observe functions

- (void) servicesChangedWithOld: (NSArray *) oldList andNew: (NSArray *) newList {
	BOOL found = NO;
	
	NSString *host = [[self.data objectForKey: @"parameter"] objectForKey: @"host"];
	NSString *service = [[self.data objectForKey: @"parameter"] objectForKey: @"service"];
	
	// loop through services
	for (NSDictionary *item in newList) {
		found = [host isEqualToString: [item valueForKey: @"host"]] &&
				[service isEqualToString: [item valueForKey: @"service"]];
		
		if (found)
			break;
	}
	
	self.match = found;
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"Bonjour", @"Rule type");
}

- (void) beingEnabled {
	Source *source = [SourcesManager.sharedSourcesManager registerRule: self toSource: @"BonjourSource"];
	
	// currently a match?
	[self servicesChangedWithOld: nil andNew: ((BonjourSource *) source).services];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unRegisterRule: self fromSource: @"BonjourSource"];
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
