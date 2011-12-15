//
//  LoopingEvidenceSource.m
//  ControlPlane
//
//  Created by David Symonds on 19/07/07.
//

#import "DSLogger.h"
#import "LoopingEvidenceSource.h"


@implementation LoopingEvidenceSource

- (id)initWithNibNamed:(NSString *)name
{
	if (!(self = [super initWithNibNamed:name]))
		return nil;

	loopInterval = (NSTimeInterval) 10;	// 10 seconds, by default
	loopTimer = nil;

	return self;
}

- (void)dealloc
{
	if (loopTimer)
		[self stop];

	[super dealloc];
}

// Private
- (void)loopTimerPoll:(NSTimer *)timer
{
	if (timer) {
		[NSThread detachNewThreadSelector:@selector(loopTimerPoll:)
					 toTarget:self
				       withObject:nil];
		return;
	}

	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[self setThreadNameFromClassName];
	DSLog(@"Updating...");
	
	SEL selector = NSSelectorFromString(@"doUpdate");
	if ([self respondsToSelector: selector])
		[self performSelector: selector];
	[pool release];
}

- (void)start
{
	if (running)
		return;

	loopTimer = [NSTimer scheduledTimerWithTimeInterval:loopInterval
						     target:self
						   selector:@selector(loopTimerPoll:)
						   userInfo:nil
						    repeats:YES];
	[self loopTimerPoll:loopTimer];

	running = YES;
}

- (void)stop
{
	if (!running)
		return;
	
	if (loopTimer && [loopTimer isValid]) {
		[loopTimer invalidate];
		loopTimer = nil;
	}
	
	SEL selector = NSSelectorFromString(@"clearCollectedData");
	if ([self respondsToSelector: selector])
		[self performSelector: selector];
	
	[self setDataCollected:NO];
	running = NO;
}

@end
