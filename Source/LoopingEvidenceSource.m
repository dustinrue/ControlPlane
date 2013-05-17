//
//  LoopingEvidenceSource.m
//  ControlPlane
//
//  Created by David Symonds on 19/07/07.
//  Updated by Vladimir Beloborodov (VladimirTechMan) on 03 May 2013.
//

#import "DSLogger.h"
#import "LoopingEvidenceSource.h"
#import "NSTimer+Invalidation.h"

@implementation LoopingEvidenceSource {
	NSTimer *loopTimer;
    SEL doUpdateSelector;
    dispatch_queue_t serialQueue;
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

    if (serialQueue) {
        dispatch_sync(serialQueue, ^{});
        dispatch_release(serialQueue);
    }

	[super dealloc];
}

// Private
- (void)loopTimerPoll:(NSTimer *)timer {
    dispatch_async(serialQueue, ^{
        @autoreleasepool {
            [self performSelector: doUpdateSelector];
        }
    });
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

    if (!serialQueue) {
        NSString *queueName = [[NSString alloc] initWithFormat:@"com.dustinrue.ControlPlane.%@",[self class]];
        serialQueue = dispatch_queue_create([queueName UTF8String], DISPATCH_QUEUE_SERIAL);
        [queueName release];
    }

	loopTimer = [[NSTimer scheduledTimerWithTimeInterval: loopInterval
												  target: self
												selector: @selector(loopTimerPoll:)
												userInfo: nil
												 repeats: YES] retain];
    [loopTimer fire];

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
