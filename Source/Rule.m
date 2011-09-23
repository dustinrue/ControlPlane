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

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	self.enabled = NO;
	self.match = NO;
	
	return self;
}

- (void) dealloc {
	[super dealloc];
}

- (void) setEnabled: (BOOL) enabled {
	if (!m_enabled && enabled)
		[self beingEnabled];
	else if (m_enabled && !enabled)
		[self beingDisabled];
	
	m_enabled = enabled;
}

#pragma mark - Subclass functions

- (void) beingEnabled {
	[self doesNotRecognizeSelector: _cmd];
}

- (void) beingDisabled {
	[self doesNotRecognizeSelector: _cmd];
}

@end
