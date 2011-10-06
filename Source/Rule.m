//
//  Rule.m
//  ControlPlane
//
//  Created by David Jennes on 18/09/11.
//  Copyright 2011. All rights reserved.
//

#import "Rule.h"

@implementation Rule

@synthesize match = m_match;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_enabled = [NSNumber numberWithBool: NO];
	m_data = [NSDictionary new];
	self.match = NO;
	
	return self;
}

- (void) dealloc {
	[m_data release];
	[super dealloc];
}

- (BOOL) enabled {
	return m_enabled.boolValue;
}

- (void) setEnabled: (BOOL) enabled {
	@synchronized(m_enabled) {
		if (!m_enabled && enabled)
			[(id<RuleProtocol>) self beingEnabled];
		else if (m_enabled && !enabled)
			[(id<RuleProtocol>) self beingDisabled];
		
		m_enabled = [NSNumber numberWithBool: enabled];
	}
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
			[m_data release];
			m_data = [data copy];
			[(id<RuleProtocol>) self loadData: [m_data objectForKey: @"value"]];
			self.enabled = old;
		}
	}
}

@end
