//
//  Rule.m
//  ControlPlane
//
//  Created by David Jennes on 18/09/11.
//  Copyright 2011. All rights reserved.
//

#import "Rule.h"

@implementation Rule

@synthesize confidence = m_confidence;
@synthesize match = m_match;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_enabled = [NSNumber numberWithBool: NO];
	m_data = [NSDictionary new];
	m_negation = [NSNumber numberWithBool: NO];
	self.confidence = [NSNumber numberWithInt: 100];
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
		if (!m_enabled.boolValue && enabled)
			[(id<RuleProtocol>) self beingEnabled];
		else if (m_enabled.boolValue && !enabled)
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

- (BOOL) negation {
	return m_negation.boolValue;
}

- (void) setNegation: (BOOL) negation {
	@synchronized(m_negation) {
		// if the user flips the negation flag, also flip the match flag!
		if (m_negation.boolValue != negation)
			self.match = !self.match;
		
		m_negation = [NSNumber numberWithBool: negation];
	}
}

@end
