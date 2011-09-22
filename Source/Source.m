//
//  Source.m
//  ControlPlane
//
//  Created by David Jennes on 18/09/11.
//  Copyright 2011. All rights reserved.
//

#import "Rule.h"
#import "Source.h"

@implementation Source

@synthesize running = m_running;

- (id) init {
	self = [super init];
	if (!self)
		return nil;
	
	self.running = NO;

	return self;
}

- (void) dealloc {
	[super dealloc];
}

#pragma mark - Subclass functions

+ (void) load {
}

- (NSString *) name {
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (void) addObserver: (Rule *) rule {
	[self doesNotRecognizeSelector: _cmd];
}

- (void) removeObserver: (Rule *) rule {
	[self doesNotRecognizeSelector: _cmd];
}

- (void) start {
	[self doesNotRecognizeSelector: _cmd];
}

- (void) stop {
	[self doesNotRecognizeSelector: _cmd];
}

@end
