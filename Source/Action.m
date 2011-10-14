//
//  Action.m
//  ControlPlane
//
//  Created by David Jennes on 01/10/11.
//  Copyright 2011. All rights reserved.
//

#import "Action.h"

@implementation Action

@synthesize enabled = m_enabled;
@synthesize delay = m_delay;
@synthesize when = m_when;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_delayLock = [NSLock new];
	m_data = [NSDictionary new];
	self.enabled = NO;
	self.delay = 0.0;
	self.when = kWhenEntering;
	
	return self;
}

- (NSDictionary *) data {
	return m_data;
}

- (void) setData: (NSDictionary *) data {
	@synchronized(m_data) {
		BOOL old = self.enabled;
		
		// shortly disable (and re-enable) the rule while setting it's data
		// needed to force a check if the rule matches the new data
		
		if (m_data != data) {
			self.enabled = NO;
			m_data = [data copy];
			[(id<ActionProtocol>) self loadData: [m_data objectForKey: @"value"]];
			self.enabled = old;
		}
	}
}

@end
