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
@synthesize data = m_data;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));

	self.enabled = NO;
	self.delay = [NSNumber numberWithDouble: 0.0];
	self.when = kWhenEntering;
	self.data = [[NSDictionary new] autorelease];
	
	return self;
}

- (void) dealloc {
	[super dealloc];
}

#pragma mark - Subclass functions

- (NSString *) name {
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (NSString *) category {
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (void) loadData {
	[self doesNotRecognizeSelector: _cmd];
}

- (BOOL) execute {
	[self doesNotRecognizeSelector: _cmd];
	return NO;
}

- (NSArray *) suggestedValues {
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}


@end
