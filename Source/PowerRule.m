//
//	PowerRule.m
//	ControlPlane
//
//	Created by David Jennes on 24/09/11.
//	Copyright 2011. All rights reserved.
//

#import "PowerRule.h"
#import "PowerSource.h"
#import "SourcesManager.h"

@implementation PowerRule

registerRuleType(PowerRule)

#pragma mark - Source observe functions

- (void) statusChangedWithOld: (NSString *) oldStatus andNew: (NSString *) newStatus {
	self.match = [[self.data objectForKey: @"parameter"] isEqualToString: newStatus];
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"Power", @"Rule type");
}

- (void) beingEnabled {
	[SourcesManager.sharedSourcesManager registerRule: self toSource: @"PowerSource"];
	
	// currently a match?
	PowerSource *source = (PowerSource *) [SourcesManager.sharedSourcesManager getSource: @"PowerSource"];
	[self statusChangedWithOld: nil andNew: source.status];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unRegisterRule: self fromSource: @"PowerSource"];
}

- (NSArray *) suggestedValues {
	return [NSArray arrayWithObjects:
			[NSDictionary dictionaryWithObjectsAndKeys:
			 @"Battery", @"parameter",
			 NSLocalizedString(@"Battery", @"PowerRule suggestion description"), @"description",
			 nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
			 @"A/C", @"parameter",
			 NSLocalizedString(@"Power Adapter", @"PowerRule suggestion description"), @"description",
			 nil],
			nil];
}

@end
