//
//  LoopingEvidenceSource.m
//  ControlPlane
//
//  Created by David Symonds on 19/07/07.
//

#import "DSLogger.h"
#import "LoopingEvidenceSource.h"
#import "NSTimer+Invalidation.h"

@implementation LoopingEvidenceSource {
	NSTimer *loopTimer;
    SEL doUpdateSelector;
}

- (id)initWithNibNamed:(NSString *)name {
    self = [super initWithNibNamed:name];
	if (self) {
        loopInterval = (NSTimeInterval) 10;	// 10 seconds, by default
        doUpdateSelector = NSSelectorFromString(@"doUpdate");
    }
	return self;
}

- (void)dealloc {
	if (loopTimer) {
		[self doStop];
    }

	[super dealloc];
}

// Private
- (void)loopTimerPoll:(NSTimer *)timer {
    @autoreleasepool {
        [self setThreadNameFromClassName];
#ifdef DEBUG_MODE
        DSLog(@"Updating...");
#endif
        [self performSelector: doUpdateSelector];
    }
}

- (void)start {
	if (running) {
		return;
    }

    if (![self respondsToSelector: doUpdateSelector]) {
#ifdef DEBUG_MODE
        DSLog(@"Error: %@ cannot respond to method 'doUpdate'", [self class]);
#endif
        [self doStop];
        return;
    }

	loopTimer = [[NSTimer scheduledTimerWithTimeInterval: loopInterval
												  target: self
												selector: @selector(loopTimerPoll:)
												userInfo: nil
												 repeats: YES] retain];

    [NSThread detachNewThreadSelector:@selector(loopTimerPoll:)
                             toTarget:self
                           withObject:loopTimer];

	running = YES;
}

- (void)stop {
	if (running) {
	 	[self doStop];
    }
}

- (void)doStop {
	loopTimer = [loopTimer checkAndInvalidate];
	
	SEL selector = NSSelectorFromString(@"clearCollectedData");
	if ([self respondsToSelector: selector]) {
		[self performSelector: selector];
    }
	
	[self setDataCollected:NO];
	running = NO;
}

@end
