//
//  LightRule.m
//  ControlPlane
//
//  Created by David Jennes on 30/09/11.
//  Copyright 2011. All rights reserved.
//

#import "LightRule.h"
#import "SensorsSource.h"

@implementation LightRule

registerRuleType(LightRule)

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_above = YES;
	m_treshold = -1.0;
	
	return self;
}

#pragma mark - Source observe functions

- (void) lightLevelChangedWithOld: (double) oldLevel andNew: (double) newLevel {
	if (m_above)
		self.match = (m_treshold <= newLevel);
	else
		self.match = (m_treshold > newLevel);
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"Ambient Light", @"Rule type");
}

- (NSString *) category {
	return NSLocalizedString(@"Sensors", @"Rule category");
}

- (void) beingEnabled {
	Source *source = [SourcesManager.sharedSourcesManager registerRule: self toSource: @"SensorsSource"];
	
	// currently a match?
	[self lightLevelChangedWithOld: -1.0 andNew: ((SensorsSource *) source).lightLevel];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unRegisterRule: self fromSource: @"SensorsSource"];
}

- (void) loadData {
	m_treshold = [[[self.data objectForKey: @"parameter"] objectForKey: @"treshold"] doubleValue];
	m_above = [[[self.data objectForKey: @"parameter"] objectForKey: @"above"] boolValue];
}

- (NSArray *) suggestedValues {
	SensorsSource *source = (SensorsSource *) [SourcesManager.sharedSourcesManager getSource: @"SensorsSource"];
	BOOL above = source.lightLevel >= 0.5;
	int percent = source.lightLevel * 100;
	NSString *desc = nil;
	
	// convert to dictionary
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
						  [NSNumber numberWithDouble: 0.5], @"treshold",
						  [NSNumber numberWithBool: above], @"above",
						  nil];
	
	// description
	if (above)
		desc = [NSString stringWithFormat: NSLocalizedString(@"Above %d%%", @"LightRule suggestion description"), percent];
	else
		desc = [NSString stringWithFormat: NSLocalizedString(@"Below %d%%", @"LightRule suggestion description"), percent];
	
	return [NSArray arrayWithObject:
			[NSDictionary dictionaryWithObjectsAndKeys:
			 dict, @"parameter",
			 desc, @"description",
			 nil]];
}

@end
