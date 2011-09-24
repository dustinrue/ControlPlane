//
//	BonjourRule.m
//	ControlPlane
//
//	Created by David Jennes on 24/09/11.
//	Copyright 2011. All rights reserved.
//

#import "BonjourRule.h"
#import "BonjourSource.h"
#import "SourcesManager.h"

@implementation BonjourRule

#pragma mark - Source observe functions

- (void) servicesChangedWithOld: (NSArray *) oldList andNew: (NSArray *) newList {
	BonjourSource *source = (BonjourSource *) [SourcesManager.sharedSourcesManager getSource: @"BonjourSource"];
	BOOL found = NO;
	
	NSString *host = [[self.data objectForKey: @"parameter"] objectAtIndex: 0];
	NSString *service = [[self.data objectForKey: @"parameter"] objectAtIndex: 1];
	
	// loop through services
	for (NSDictionary *item in source.services) {
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
	[SourcesManager.sharedSourcesManager registerRule: self toSource: @"BonjourSource"];
	
	// currently a match?
	BonjourSource *source = (BonjourSource *) [SourcesManager.sharedSourcesManager getSource: @"BonjourSource"];
	[self servicesChangedWithOld: nil andNew: source.services];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unRegisterRule: self fromSource: @"BonjourSource"];
}

- (NSArray *) suggestedValues {
	BonjourSource *source = (BonjourSource *) [SourcesManager.sharedSourcesManager getSource: @"BonjourSource"];
	NSMutableArray *result = [[NSArray new] autorelease];
	
	// loop through services
	for (NSDictionary *item in source.services) {
		NSString *host = [item valueForKey: @"host"];
		NSString *service = [item valueForKey: @"service"];
		
		NSArray *parameter = [NSArray arrayWithObjects: host, service, nil];
		NSString *description = [NSString stringWithFormat: @"%@ on %@", host, service];
		
		[result addObject: [NSDictionary dictionaryWithObjectsAndKeys:
							parameter, @"parameter",
							description, @"description", nil]];
	}
	
	return result;
}

@end
