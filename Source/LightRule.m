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

#pragma mark - Source observe functions

- (void) lightLevelChangedWithOld: (double) oldLevel andNew: (double) newLevel {
	NSNumber *treshold = [[self.data objectForKey: @"parameter"] objectForKey: @"treshold"];
	NSNumber *above = [[self.data objectForKey: @"parameter"] objectForKey: @"above"];
	
	if (above.boolValue)
		self.match = (treshold.doubleValue <= newLevel);
	else
		self.match = (treshold.doubleValue > newLevel);
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"Light", @"Rule type");
}

- (void) beingEnabled {
	Source *source = [SourcesManager.sharedSourcesManager registerRule: self toSource: @"SensorsSource"];
	
	// currently a match?
	[self lightLevelChangedWithOld: -1.0 andNew: ((SensorsSource *) source).lightLevel];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unRegisterRule: self fromSource: @"SensorsSource"];
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
