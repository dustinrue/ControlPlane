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

registerRuleType(KeyboardBrightnessRule)

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

- (void) loadData {
	m_treshold = [[self.data valueForKeyPath: @"parameter.treshold"] doubleValue];
	m_above = [[self.data valueForKeyPath: @"parameter.above"] boolValue];
}

- (NSArray *) suggestedValues {
	SensorsSource *source = (SensorsSource *) [SourcesManager.sharedSourcesManager getSource: @"SensorsSource"];
	BOOL above = source.keyboardBrightness >= 0.5;
	int percent = source.keyboardBrightness * 100;
	NSString *desc = nil;
	
	// convert to dictionary
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
						  [NSNumber numberWithDouble: 0.5], @"treshold",
						  [NSNumber numberWithBool: above], @"above",
						  nil];
	
	// description
	if (above)
		desc = [NSString stringWithFormat:
				NSLocalizedString(@"Above %d%%", @"DisplayBrightnessRule suggestion description"),
				percent];
	else
		desc = [NSString stringWithFormat:
				NSLocalizedString(@"Below %d%%", @"DisplayBrightnessRule suggestion description"),
				percent];
	
	return [NSArray arrayWithObject:
			[NSDictionary dictionaryWithObjectsAndKeys:
			 dict, @"parameter",
			 desc, @"description",
			 nil]];
}

@end
