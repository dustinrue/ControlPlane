//
//  MonitorRule.m
//  ControlPlane
//
//  Created by David Jennes on 30/09/11.
//  Copyright 2011. All rights reserved.
//

#import "MonitorRule.h"
#import "MonitorSource.h"

@implementation MonitorRule

registerRuleType(MonitorRule)

- (id) init {
    self = [super init];
    
    return self;
}

#pragma mark - Source observe functions

- (void) devicesChangedWithOld: (NSDictionary *) oldList andNew: (NSDictionary *) newList {
	self.match = ([newList objectForKey: m_serial] != nil);
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"Monitor", @"Rule type");
}

- (NSString *) category {
	return NSLocalizedString(@"Devices", @"Rule category");
}

- (void) beingEnabled {
	Source *source = [SourcesManager.sharedSourcesManager registerRule: self toSource: @"MonitorSource"];
	
	// currently a match?
	[self devicesChangedWithOld: nil andNew: ((MonitorSource *) source).devices];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unRegisterRule: self fromSource: @"MonitorSource"];
}

- (void) loadData {
	m_serial = [self.data objectForKey: @"parameter"];
}

- (NSArray *) suggestedValues {
	MonitorSource *source = (MonitorSource *) [SourcesManager.sharedSourcesManager getSource: @"MonitorSource"];
	NSMutableArray *result = [[NSArray new] autorelease];
	
	// loop through devices
	for (NSString *serial in source.devices)
		[result addObject: [NSDictionary dictionaryWithObjectsAndKeys:
							serial, @"parameter",
							[source.devices objectForKey: serial], @"description",
							nil]];
	
	return result;
}

@end
