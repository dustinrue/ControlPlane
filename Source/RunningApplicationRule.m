//
//	RunningApplicationRule.m
//	ControlPlane
//
//	Created by David Jennes on 24/09/11.
//	Copyright 2011. All rights reserved.
//

#import "RunningApplicationRule.h"
#import "RunningApplicationSource.h"

@implementation RunningApplicationRule

registerRuleType(RunningApplicationRule)

#pragma mark - Source observe functions

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_identifier = nil;
	
	return self;
}

- (void) applicationsChangedWithOld: (NSArray *) oldList andNew: (NSArray *) newList {
	BOOL found = NO;
	
	// loop through apps
	for (NSDictionary *app in newList) {
		found = [m_identifier isEqualToString: [app valueForKey: @"identifier"]];
		if (found)
			break;
	}
	
	self.match = found;
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"Running Application", @"Rule type");
}

- (NSString *) category {
	return NSLocalizedString(@"System", @"Rule category");
}

- (void) beingEnabled {
	Source *source = [SourcesManager.sharedSourcesManager registerRule: self toSource: @"RunningApplicationSource"];
	
	// currently a match?
	[self applicationsChangedWithOld: nil andNew: ((RunningApplicationSource *) source).applications];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unRegisterRule: self fromSource: @"RunningApplicationSource"];
}

- (void) loadData {
	m_identifier = [self.data objectForKey: @"parameter"];
}

- (NSArray *) suggestedValues {
	RunningApplicationSource *source = (RunningApplicationSource *) [SourcesManager.sharedSourcesManager getSource: @"RunningApplicationSource"];
	NSMutableArray *result = [[NSArray new] autorelease];
	
	// loop through apps
	for (NSDictionary *app in source.applications)
		[result addObject: [NSDictionary dictionaryWithObjectsAndKeys:
							[app valueForKey: @"identifier"], @"parameter",
							[app valueForKey: @"name"], @"description", nil]];
	
	return result;
}

@end
