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
    SEL doUpdateSelector;
}

- (id)initWithNibNamed:(NSString *)name {
	if (!(self = [super initWithNibNamed:name])) {
		return nil;
    }

	loopInterval = (NSTimeInterval) 10;	// 10 seconds, by default
	loopTimer = nil;

    doUpdateSelector = NSSelectorFromString(@"doUpdate");
    
	return self;
}

- (void)dealloc {
	if (loopTimer) {
		[self stop];
    }

	[super dealloc];
}

// Private
- (void)loopTimerPoll:(NSTimer *)timer {
	if (timer) {
		[NSThread detachNewThreadSelector:@selector(loopTimerPoll:)
					 toTarget:self
				       withObject:nil];
		return;
	}

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
        DSLog(@"Error: %@ cannot respond to selector 'doUpdate'", [self class]);
        return;
    }

	loopTimer = [[NSTimer scheduledTimerWithTimeInterval: loopInterval
												  target: self
												selector: @selector(loopTimerPoll:)
												userInfo: nil
												 repeats: YES] retain];
	[self loopTimerPoll:loopTimer];

	running = YES;
}

- (void)stop {
	if (!running) {
		return;
    }
	
	loopTimer = [loopTimer checkAndInvalidate];
	
	SEL selector = NSSelectorFromString(@"clearCollectedData");
	if ([self respondsToSelector: selector]) {
		[self performSelector: selector];
    }
	
	[self setDataCollected:NO];
	running = NO;
}

@end
