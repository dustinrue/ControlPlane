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
		[(id<LoopingSourceProtocol>) self checkData];
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

@end
