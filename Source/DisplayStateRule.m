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

#pragma mark - Source observe functions

- (void) displayStateChangedWithOld: (eDisplayState) oldState andNew: (eDisplayState) newState {
	NSNumber *parameter = [self.data objectForKey: @"parameter"];
	
	self.match = (parameter.intValue == newState);
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
