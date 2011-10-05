//
//  KeyboardBrightnessRule.m
//  ControlPlane
//
//  Created by David Jennes on 30/09/11.
//  Copyright 2011. All rights reserved.
//

#import "KeyboardBrightnessRule.h"
#import "SensorsSource.h"

@implementation KeyboardBrightnessRule

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_above = YES;
	m_treshold = -1.0;
	
	return self;
}

#pragma mark - Source observe functions

- (void) keyboardBrightnessChangedWithOld: (double) oldLevel andNew: (double) newLevel {
	if (m_above)
		self.match = (m_treshold <= newLevel);
	else
		self.match = (m_treshold > newLevel);
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"Display Brightness", @"Rule type");
}

- (NSString *) category {
	return NSLocalizedString(@"Sensors", @"Rule category");
}

- (void) beingEnabled {
	Source *source = [SourcesManager.sharedSourcesManager registerRule: self toSource: @"SensorsSource"];
	
	// currently a match?
	[self keyboardBrightnessChangedWithOld: -1.0 andNew: ((SensorsSource *) source).keyboardBrightness];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unRegisterRule: self fromSource: @"SensorsSource"];
}

- (void) loadData: (id) data {
	m_treshold = [[data objectForKey: @"treshold"] doubleValue];
	m_above = [[data objectForKey: @"above"] boolValue];
}

- (NSString *) describeValue: (id) value {
	if ([[value objectForKey: @"above"] boolValue])
		return [NSString stringWithFormat:
				NSLocalizedString(@"Above %d%%", @"KeyboardBrightnessRule value description"),
				[value valueForKey: @"treshold"]];
	else
		return [NSString stringWithFormat:
				NSLocalizedString(@"Below %d%%", @"KeyboardBrightnessRule value description"),
				[value valueForKey: @"treshold"]];
}

- (NSArray *) suggestedValues {
	SensorsSource *source = (SensorsSource *) [SourcesManager.sharedSourcesManager getSource: @"SensorsSource"];
	BOOL above = source.keyboardBrightness >= 0.5;
	
	// convert to dictionary
	return [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithDouble: 0.5], @"treshold",
			[NSNumber numberWithBool: above], @"above",
			nil];
}

@end
