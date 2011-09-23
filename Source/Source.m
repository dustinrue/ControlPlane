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
@synthesize listenersCount = m_listenersCount;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	self.running = NO;
	self.listenersCount = 0;
	
	return self;
}

- (void) dealloc {
	[super dealloc];
}

- (void) setListenersCount: (unsigned int) listenersCount {
	if (!self.running && listenersCount > 0)
		[self start];
	else if (self.running && listenersCount == 0)
		[self stop];
	
	m_listenersCount = listenersCount;
}

- (NSString *) name {
	return NSStringFromClass(self.class);
}

#pragma mark - Subclass functions

+ (void) load {
	[self doesNotRecognizeSelector: _cmd];
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
