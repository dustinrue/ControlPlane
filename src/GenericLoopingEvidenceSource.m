//
//  GenericLoopingEvidenceSource.m
//  MarcoPolo
//
//  Created by David Symonds on 19/07/07.
//

#import "GenericLoopingEvidenceSource.h"


@implementation GenericLoopingEvidenceSource

- (id)init
{
	if (!(self = [super init]))
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
	[self performSelector:@selector(doUpdate)];
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

	[loopTimer invalidate];
	loopTimer = nil;

	[self performSelector:@selector(clearCollectedData)];
	[self setDataCollected:NO];

	running = NO;
}

@end
