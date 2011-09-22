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

- (id) init {
	self = [super init];
	if (!self)
		return nil;
	
	return self;
}

- (void) dealloc {
	
	[super dealloc];
}

@end
