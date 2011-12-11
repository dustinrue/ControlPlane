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

- (id) init {
    self = [super init];
    
	m_serial = nil;
	
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

- (NSString *) helpText {
	return NSLocalizedString(@"An attached monitor is named", @"MonitorRule");
}

- (NSArray *) observedSources {
	return [NSArray arrayWithObject: MonitorSource.class];
}

- (void) loadData: (id) data {
	m_serial = data;
}

- (NSString *) describeValue: (id) value {
	MonitorSource *source = (MonitorSource *) [SourcesManager.sharedSourcesManager getSource: MonitorSource.class];
	NSString *name = [source.devices objectForKey: value];
	
	if (name)
		return name;
	else
		return NSLocalizedString(@"Unknown Device", @"MonitorRule value description");
}

- (NSArray *) suggestedValues {
	MonitorSource *source = (MonitorSource *) [SourcesManager.sharedSourcesManager getSource: MonitorSource.class];
	
	return source.devices.allKeys;
}

@end
