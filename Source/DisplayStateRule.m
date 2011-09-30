//
//	DisplayStateRule.m
//	ControlPlane
//
//	Created by David Jennes on 30/09/11.
//	Copyright 2011. All rights reserved.
//

#import "DisplayStateRule.h"
#import "PowerSource.h"

@implementation DisplayStateRule

registerRuleType(DisplayStateRule)

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_state = kDisplayOn;
	
	return self;
}

#pragma mark - Source observe functions

- (void) displayStateChangedWithOld: (eDisplayState) oldState andNew: (eDisplayState) newState {
	self.match = (m_state == newState);
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"Source", @"Rule type");
}

- (NSString *) category {
	return NSLocalizedString(@"Power", @"Rule category");
}

- (void) beingEnabled {
	Source *source = [SourcesManager.sharedSourcesManager registerRule: self toSource: @"PowerSource"];
	
	// currently a match?
	[self displayStateChangedWithOld: kDisplayOn andNew: ((PowerSource *) source).displayState];
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
			 [NSNumber numberWithInt: kDisplayOn], @"parameter",
			 NSLocalizedString(@"On", @"DisplayStateRule suggestion description"), @"description",
			 nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
			 [NSNumber numberWithInt: kDisplayDimmed], @"parameter",
			 NSLocalizedString(@"Dimmed", @"DisplayStateRule suggestion description"), @"description",
			 nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
			 [NSNumber numberWithInt: kDisplayOff], @"parameter",
			 NSLocalizedString(@"Off", @"DisplayStateRule suggestion description"), @"description",
			 nil],
			nil];
}

@end
