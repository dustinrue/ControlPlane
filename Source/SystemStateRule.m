//
//  SystemStateRule.m
//  ControlPlane
//
//  Created by David Jennes on 30/09/11.
//  Copyright 2011. All rights reserved.
//

#import "SystemStateRule.h"
#import "SystemStateSource.h"

@implementation SystemStateRule

registerRuleType(SystemStateRule)

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_state = kSystemNormal;
	
	return self;
}

#pragma mark - Source observe functions

- (void) stateChangedWithOld: (eSystemState) oldState andNew: (eSystemState) newState {
	self.match = (m_state == newState);
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"System State", @"Rule type");
}

- (NSString *) category {
	return NSLocalizedString(@"Power", @"Rule category");
}

- (void) beingEnabled {
	Source *source = [SourcesManager.sharedSourcesManager registerRule: self toSource: @"SystemStateSource"];
	
	// currently a match?
	[self stateChangedWithOld: kSystemNormal andNew: ((SystemStateSource *) source).state];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unRegisterRule: self fromSource: @"SystemStateSource"];
}

- (void) loadData {
	m_state = [[self.data objectForKey: @"parameter"] intValue];
}

- (NSArray *) suggestedValues {
	return [NSArray arrayWithObjects:
			[NSDictionary dictionaryWithObjectsAndKeys:
			 [NSNumber numberWithInt: kSystemNormal], @"parameter",
			 NSLocalizedString(@"Normal", @"SystemStateRule suggestion description"), @"description",
			 nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
			 [NSNumber numberWithInt: kSystemSleep], @"parameter",
			 NSLocalizedString(@"Sleep", @"SystemStateRule suggestion description"), @"description",
			 nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
			 [NSNumber numberWithInt: kSystemWake], @"parameter",
			 NSLocalizedString(@"Wake", @"SystemStateRule suggestion description"), @"description",
			 nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
			 [NSNumber numberWithInt: kSystemPowerOff], @"parameter",
			 NSLocalizedString(@"Power Off", @"SystemStateRule suggestion description"), @"description",
			 nil],
			nil];
}

@end
