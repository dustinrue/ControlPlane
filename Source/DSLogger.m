//
//  DSLogger.m
//  ControlPlane
//
//  Created by David Symonds on 22/07/07.
//  Modified by Vladimir Beloborodov on 01 Apr 2013.
//

#import "DSLogger.h"


#define DSLOGGER_CAPACITY	128

static DSLogger *sharedLogger = nil;

@implementation DSLogger {
    dispatch_queue_t serialQueue;

	NSDateFormatter *timestampFormatter;

	// Clustering
	NSTimeInterval clusterThreshold;
	NSDate *clusterStartDate;
	NSString *lastFunction;

	// Ring buffer
	NSMutableArray *buffer;
	int startIndex, count;
}

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedLogger = [[self alloc] init];
    });
}

+ (DSLogger *)sharedLogger {
	return sharedLogger;
}

- (id)init {
	if (!(self = [super init]))
		return nil;

	timestampFormatter = [[NSDateFormatter alloc] init];
	[timestampFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
	[timestampFormatter setDateFormat:@"HH:mm:ss.SSS"];

	clusterThreshold = 0.5;
	clusterStartDate = [[NSDate distantPast] retain];
	lastFunction = [[NSString alloc] init];

	buffer = [[NSMutableArray alloc] initWithCapacity:DSLOGGER_CAPACITY];
	startIndex = count = 0;

    serialQueue = dispatch_queue_create("ControlPlane.DSLogger", DISPATCH_QUEUE_SERIAL);

	return self;
}

- (void)dealloc {
    dispatch_sync(serialQueue, ^{
        [timestampFormatter release];
        [clusterStartDate release];
        [lastFunction release];
        [buffer release];
    });
    dispatch_release(serialQueue);

	[super dealloc];
}

- (void)logFromFunction:(NSString *)fnName withInfo:(NSString *)info {
    [[self class] logFromFunction:fnName withInfo:info];
}

+ (void)logFromFunction:(NSString *)fnName withInfo:(NSString *)info {
#ifdef DEBUG_MODE
	NSLog(@"%@ %@", fnName, info);
#endif

    NSString *fnNameCopy = [fnName copy], *infoCopy = [info copy];
	NSDate *now = [[NSDate alloc] init];
    dispatch_async(sharedLogger->serialQueue, ^{
        @autoreleasepool {
            [sharedLogger doLogFromFunction:fnNameCopy withInfo:infoCopy timeStamp:now];
        }
        [now release];
        [fnNameCopy release];
        [infoCopy release];
    });
}

- (void)doLogFromFunction:(NSString *)func withInfo:(NSString *)info timeStamp:(NSDate *)timeSt {
	NSString *line;

	if (([timeSt timeIntervalSinceDate:clusterStartDate] < clusterThreshold) && [lastFunction isEqualToString:func])
		line = [@"\t" stringByAppendingString:info];
	else {
		[clusterStartDate release];
        clusterStartDate = [timeSt retain];
        
        [lastFunction release];
        lastFunction = [func retain];
        
		line = [NSString stringWithFormat:@"%@ %@\n\t%@", [timestampFormatter stringFromDate:timeSt], func, info];
	}

	if (count < DSLOGGER_CAPACITY) {
		[buffer addObject:line];
		++count;
	} else {
		buffer[startIndex] = line;
        ++startIndex;
        startIndex %= DSLOGGER_CAPACITY;
	}
}

- (NSString *)buffer {
	NSMutableString *buf = [NSMutableString string];

    dispatch_suspend(serialQueue);
	int i = startIndex, cnt = count;

	while (cnt > 0) {
		[buf appendString:buffer[i]];
		if (cnt > 1)
			[buf appendString:@"\n"];

        ++i;
        i %= DSLOGGER_CAPACITY;
		--cnt;
	}

    dispatch_resume(serialQueue);
	return buf;
}

@end
