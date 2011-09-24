//
//	PowerRule.m
//	ControlPlane
//
//	Created by David Jennes on 24/09/11.
//	Copyright 2011. All rights reserved.
//

#import "RunningApplicationRule.h"
#import "RunningApplicationSource.h"
#import "SourcesManager.h"

@implementation RunningApplicationRule

#pragma mark - Source observe functions

- (void) statusChangedWithOld: (NSArray *) oldList andNew: (NSArray *) newList {
	RunningApplicationSource *source = (RunningApplicationSource *) [SourcesManager.sharedSourcesManager getSource: @"RunningApplicationSource"];
	NSString *needle = [self.data objectForKey: @"parameter"];
	BOOL found = NO;
	
	// loop through apps
	for (NSDictionary *app in source.runningApplications) {
		found = [needle isEqualToString: [app valueForKey: @"identifier"]];
		if (found)
			break;
	}
	
	self.match = found;
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"Running Application", "Rule type");
}

- (void) beingEnabled {
	[SourcesManager.sharedSourcesManager registerRule: self toSource: @"RunningApplicationSource"];
	
	// currently a match?
	RunningApplicationSource *source = (RunningApplicationSource *) [SourcesManager.sharedSourcesManager getSource: @"RunningApplicationSource"];
	[self statusChangedWithOld: nil andNew: source.runningApplications];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unRegisterRule: self fromSource: @"RunningApplicationSource"];
}

- (NSArray *) suggestedValues {
	RunningApplicationSource *source = (RunningApplicationSource *) [SourcesManager.sharedSourcesManager getSource: @"RunningApplicationSource"];
	NSMutableArray *result = [[NSArray new] autorelease];
	
	// loop through apps
	for (NSDictionary *app in source.runningApplications)
		[result addObject: [NSDictionary dictionaryWithObjectsAndKeys:
							[app valueForKey: @"identifier"], @"parameter",
							[app valueForKey: @"name"], @"description", nil]];
	
	return result;
}

@end
