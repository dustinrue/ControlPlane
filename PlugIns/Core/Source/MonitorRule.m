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

- (void) beingEnabled {
	Source *source = [SourcesManager.sharedSourcesManager registerRule: self toSource: @"MonitorSource"];
	
	// currently a match?
	[self devicesChangedWithOld: nil andNew: ((MonitorSource *) source).devices];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unregisterRule: self fromSource: @"MonitorSource"];
}

- (void) loadData: (id) data {
	m_serial = data;
}

- (NSString *) describeValue: (id) value {
	MonitorSource *source = (MonitorSource *) [SourcesManager.sharedSourcesManager getSource: @"MonitorSource"];
	NSString *name = [source.devices objectForKey: value];
	
	if (name)
		return name;
	else
		return NSLocalizedString(@"Unknown Device", @"MonitorRule value description");
}

- (NSArray *) suggestedValues {
	MonitorSource *source = (MonitorSource *) [SourcesManager.sharedSourcesManager getSource: @"MonitorSource"];
	
	return source.devices.allKeys;
}

@end
