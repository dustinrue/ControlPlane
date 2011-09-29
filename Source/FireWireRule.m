//
//  FireWireRule.m
//  ControlPlane
//
//  Created by David Jennes on 29/09/11.
//  Copyright 2011. All rights reserved.
//

#import "FireWireRule.h"
#import "FireWireSource.h"

@implementation FireWireRule

registerRuleType(FireWireRule)

#pragma mark - Source observe functions

- (void) devicesChangedWithOld: (NSDictionary *) oldList andNew: (NSDictionary *) newList {
	NSNumber *guid = [self.data objectForKey: @"parameter"];
	
	self.match = ([newList objectForKey: guid] != nil);
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"FireWire", @"Rule type");
}

- (void) beingEnabled {
	Source *source = [SourcesManager.sharedSourcesManager registerRule: self toSource: @"FireWireSource"];
	
	// currently a match?
	[self devicesChangedWithOld: nil andNew: ((FireWireSource *) source).devices];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unRegisterRule: self fromSource: @"FireWireSource"];
}

- (NSArray *) suggestedValues {
	FireWireSource *source = (FireWireSource *) [SourcesManager.sharedSourcesManager getSource: @"FireWireSource"];
	NSMutableArray *result = [[NSArray new] autorelease];
	
	// loop through devices
	for (NSDictionary *item in source.devices) {
		NSString *description = [NSString stringWithFormat: @"%@ (%@)",
								 [item valueForKey: @"name"],
								 [item valueForKey: @"vendor"]];
		
		[result addObject: [NSDictionary dictionaryWithObjectsAndKeys:
							[item valueForKey: @"guid"], @"parameter",
							description, @"description", nil]];
	}
	
	return result;
}

@end
