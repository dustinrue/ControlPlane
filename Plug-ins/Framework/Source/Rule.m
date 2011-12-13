//
//  Rule.m
//  ControlPlane
//
//  Created by David Jennes on 18/09/11.
//  Copyright 2011. All rights reserved.
//

#import "Rule.h"
#import "Source.h"
#import "SourcesManager.h"

@interface Rule (Private)

- (void) beingEnabled;
- (void) beingDisabled;

@end

@implementation Rule

@synthesize match = m_match;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	if (!self) return nil;
	
	m_data = [NSDictionary new];
	m_enabledLock = [NSLock new];
	m_matchLock = [NSRecursiveLock new];
	
	self.enabled = NO;
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
			[self beingEnabled];
		else if (m_enabled && !enabled)
			[self beingDisabled];
		
		m_enabled = enabled;
	}
}

- (NSDictionary *) data {
	return m_data;
}

- (void) setData: (NSDictionary *) data {
	@synchronized(m_data) {
		// shortly disable (and re-enable) the rule while setting it's data
		// needed to force a check if the rule matches the new data
		
		if (m_data != data) {
			self.enabled = NO;
			m_data = [data copy];
			
			// negation
			self.negation = [[m_data objectForKey: @"negation"] boolValue];
			
			// load value data
			id value = [m_data objectForKey: @"value"];
			ZAssert(value, @"Data contains no 'value' key");
			[(id<RuleProtocol>) self loadData: value];
			
			// enable if needed
			self.enabled = [[m_data objectForKey: @"enabled"] boolValue];
		}
	}
}

- (BOOL) match {
	return m_match;
}

- (void) setMatch: (BOOL) match {
	@synchronized(m_matchLock) {
		m_match = self.negation ^ match;
	}
}

- (BOOL) negation {
	return m_negation;
}

- (void) setNegation: (BOOL) negation {
	@synchronized(m_matchLock) {
		if (m_negation == negation)
			return;
		
		// if the user flips the negation flag, also flip the match flag!
		BOOL old = self.match;
		m_negation = negation;
		self.match = old;
	}
}

#pragma mark - Private methods

- (void) beingEnabled {
	for (Class source in ((id<RuleProtocol>) self).observedSources) {
		// register with source
		[SourcesManager.sharedSourcesManager registerRule: self toSource: source];
		
		// currently a match?
		[[SourcesManager.sharedSourcesManager getSource: source] checkObserver: self];
	}
}

- (void) beingDisabled {
	for (Class source in ((id<RuleProtocol>) self).observedSources)
		[SourcesManager.sharedSourcesManager unregisterRule: self fromSource: source];
}

@end
