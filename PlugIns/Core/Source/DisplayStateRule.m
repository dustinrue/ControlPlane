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
	[SourcesManager.sharedSourcesManager unregisterRule: self fromSource: @"PowerSource"];
}

- (void) loadData: (id) data {
	m_state = [data unsignedIntValue];
}

- (NSString *) describeValue: (id) value {
	switch ([value unsignedIntValue]) {
		case kDisplayOn:
			return NSLocalizedString(@"On", @"DisplayStateRule value description");
		case kDisplayDimmed:
			return NSLocalizedString(@"Dimmed", @"DisplayStateRule value description");
		case kDisplayOff:
			return NSLocalizedString(@"Off", @"DisplayStateRule value description");
		default:
			return @"";
	}
}

- (NSArray *) suggestedValues {
	return [NSArray arrayWithObjects:
			[NSNumber numberWithUnsignedInt: kDisplayOn],
			[NSNumber numberWithUnsignedInt: kDisplayDimmed],
			[NSNumber numberWithUnsignedInt: kDisplayOff],
			nil];
}

@end
