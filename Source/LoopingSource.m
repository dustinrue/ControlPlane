//
//	LoopingSource.m
//	ControlPlane
//
//	Created by David Jennes on 21/09/11.
//	Copyright 2011. All rights reserved.
//

#import "LoopingSource.h"

@implementation LoopingSource

@synthesize interval = m_interval;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	self.interval = 10.0;
	
	return self;
}

- (void) run {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	NSThread.currentThread.name = self.name;
	
	while (self.running) {
		[self checkData];
		[NSThread sleepForTimeInterval: self.interval];
	}
	
	[pool release];
}

- (void) start {
	if (self.running)
		return;
	
	self.running = YES;
	[NSThread detachNewThreadSelector: @selector(run)
							 toTarget: self
						   withObject: nil];
}

- (void) stop {
	if (!self.running)
		return;
	
	// thread will stop with this
	self.running = NO;
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

- (void) checkData {
	[self doesNotRecognizeSelector: _cmd];
}

@end
