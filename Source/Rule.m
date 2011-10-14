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
	
	m_data = [NSDictionary new];
	m_enabledLock = [NSLock new];
	m_negationLock = [NSLock new];
	
	self.enabled = NO;
	self.confidence = 100;
	self.match = NO;
	self.negation = NO;
	
	return self;
}

- (BOOL) enabled {
	return m_enabled;
}

- (void) setEnabled: (BOOL) enabled {
	@synchronized(m_enabledLock) {
		if (!m_enabled && enabled)
			[(id<RuleProtocol>) self beingEnabled];
		else if (m_enabled && !enabled)
			[(id<RuleProtocol>) self beingDisabled];
		
		m_enabled = enabled;
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
			m_data = [data copy];
			[(id<RuleProtocol>) self loadData: [m_data objectForKey: @"value"]];
			self.enabled = old;
		}
	}
}

- (BOOL) negation {
	return m_negation;
}

- (void) setNegation: (BOOL) negation {
	@synchronized(m_negationLock) {
		// if the user flips the negation flag, also flip the match flag!
		if (m_negation != negation)
			self.match = !self.match;
		
		m_negation = negation;
	}
}

@end
