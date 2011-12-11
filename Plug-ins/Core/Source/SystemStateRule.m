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

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	if (!self) return nil;
	
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

- (NSString *) helpText {
	return NSLocalizedString(@"System state is", @"SystemStateRule");
}

- (NSArray *) observedSources {
	return [NSArray arrayWithObject: SystemStateSource.class];
}

- (void) loadData: (id) data {
	m_state = [data unsignedIntValue];
}

- (NSString *) describeValue: (id) value {
	switch ([value unsignedIntValue]) {
		case kSystemNormal:
			return NSLocalizedString(@"Normal", @"SystemStateRule value description");
		case kSystemSleep:
			return NSLocalizedString(@"Sleeping", @"SystemStateRule value description");
		case kSystemWake:
			return NSLocalizedString(@"Waking", @"SystemStateRule value description");
		case kSystemPowerOff:
			return NSLocalizedString(@"Powering Off", @"SystemStateRule value description");
		default:
			return NSLocalizedString(@"Unknown", @"SystemStateRule value description");
	}
}

- (NSArray *) suggestedValues {
	return [NSArray arrayWithObjects:
			[NSNumber numberWithUnsignedInt: kSystemNormal],
			[NSNumber numberWithUnsignedInt: kSystemSleep],
			[NSNumber numberWithUnsignedInt: kSystemWake],
			[NSNumber numberWithUnsignedInt: kSystemPowerOff],
			nil];
}

@end
