//
//  GenericLoopingEvidenceSource.m
//  ControlPlane
//
//  Created by David Symonds on 19/07/07.
//  Updated by Vladimir Beloborodov (VladimirTechMan) on 03 May 2013.
//

#import "DSLogger.h"
#import "GenericLoopingEvidenceSource.h"

@implementation GenericLoopingEvidenceSource {
    SEL doUpdateSelector;
    dispatch_source_t loopTimer;
    dispatch_queue_t serialQueue;
}

- (id)init {
    self = [super init];
	if (self) {
        loopInterval = (NSTimeInterval) 10;	// 10 seconds, by default
        loopLeeway = (NSTimeInterval) 1;
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

    loopTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, serialQueue);
    dispatch_source_set_event_handler(loopTimer, ^{
        @autoreleasepool {
            [self performSelector:doUpdateSelector];
        }
    });
    dispatch_source_set_timer(loopTimer, DISPATCH_TIME_NOW,
                              (int64_t) (loopInterval * NSEC_PER_SEC),
                              (int64_t) (loopLeeway * NSEC_PER_SEC));
    dispatch_resume(loopTimer);

	running = YES;
}

- (void)stop {
	if (running) {
        [self doStop];
    }
}

- (void)doStop {
    if (loopTimer) {
        dispatch_source_cancel(loopTimer);
        dispatch_release(loopTimer);
        loopTimer = NULL;
    }

	SEL selector = NSSelectorFromString(@"clearCollectedData");
	if ([self respondsToSelector: selector]) {
		[self performSelector: selector];
    }

	[self setDataCollected:NO];
	running = NO;
}

@end
