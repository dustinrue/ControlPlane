//
//  Context.m
//  ControlPlane
//
//  Created by David Jennes on 23/09/11.
//  Copyright 2011. All rights reserved.
//

#import "Action.h"
#import "Context.h"
#import "Rule.h"

@implementation Context

@synthesize name = m_name;
@synthesize active = m_active;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	self.name = nil;
	self.active = NO;
	m_rules = [NSMutableArray new];
	m_actions = [NSMutableArray new];
	
	return self;
}

- (void) dealloc {
	[m_rules release];
	[m_actions release];
	
	[super dealloc];
}

@end
