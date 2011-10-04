//
//  Rule.m
//  ControlPlane
//
//  Created by David Jennes on 18/09/11.
//  Copyright 2011. All rights reserved.
//

#import "Rule.h"

@implementation Rule

@synthesize enabled = m_enabled;
@synthesize match = m_match;
@synthesize data = m_data;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	self.enabled = NO;
	self.match = NO;
	self.data = [[NSDictionary new] autorelease];
	
	return self;
}

- (void) dealloc {
	[super dealloc];
}

- (void) setEnabled: (BOOL) enabled {
	if (!m_enabled && enabled)
		[(id<RuleProtocol>) self beingEnabled];
	else if (m_enabled && !enabled)
		[(id<RuleProtocol>) self beingDisabled];
	
	m_enabled = enabled;
}

- (void) setData: (NSDictionary *) data {
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

@end
