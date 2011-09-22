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
	if (!self)
		return nil;
	
	self.running = NO;
	
	return self;
}

- (void) run {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[[NSThread currentThread] setName: self.name];
	
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
	[NSThread detachNewThreadSelector:@selector(run)
							 toTarget:self
						   withObject:nil];
}

- (void) stop {
	if (!self.running)
		return;
	
	// thread will stop with this
	self.running = NO;
}

- (void) checkData {
	[self doesNotRecognizeSelector: _cmd];
}

@end
