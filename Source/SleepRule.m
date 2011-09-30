//
//  SleepRule.m
//  ControlPlane
//
//  Created by David Jennes on 30/09/11.
//  Copyright 2011. All rights reserved.
//

#import "SleepRule.h"
#import "SleepSource.h"

@implementation SleepRule

registerRuleType(SleepRule)

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_state = kSleepNormal;
	
	return self;
}

#pragma mark - Source observe functions

- (void) stateChangedWithOld: (eSleepState) oldState andNew: (eSleepState) newState {
	self.match = (m_state == newState);
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"Sleep", @"Rule type");
}

- (NSString *) category {
	return NSLocalizedString(@"Power", @"Rule category");
}

- (void) beingEnabled {
	Source *source = [SourcesManager.sharedSourcesManager registerRule: self toSource: @"SleepSource"];
	
	// currently a match?
	[self stateChangedWithOld: kSleepNormal andNew: ((SleepSource *) source).state];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unRegisterRule: self fromSource: @"PowerSource"];
}

- (void) loadData {
	m_state = [[self.data objectForKey: @"parameter"] intValue];
}

- (NSArray *) suggestedValues {
	return [NSArray arrayWithObjects:
			[NSDictionary dictionaryWithObjectsAndKeys:
			 [NSNumber numberWithInt: kSleepNormal], @"parameter",
			 NSLocalizedString(@"Normal", @"SleepRule suggestion description"), @"description",
			 nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
			 [NSNumber numberWithInt: kSleepSleep], @"parameter",
			 NSLocalizedString(@"Sleep", @"SleepRule suggestion description"), @"description",
			 nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
			 [NSNumber numberWithInt: kSleepWake], @"parameter",
			 NSLocalizedString(@"Wake", @"SleepRule suggestion description"), @"description",
			 nil],
			nil];
}

@end
