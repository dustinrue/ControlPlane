//
//  DSLogger.m
//  ControlPlane
//
//  Created by David Symonds on 22/07/07.
//  Modified by Vladimir Beloborodov on 01 Apr 2013.
//
//  IMPORTANT: This code is intended to be compiled for the ARC mode
//

#pragma mark -
#pragma mark DSLogRecord (used by DSLogger)

@interface DSLogRecord : NSObject

@property (strong,nonatomic) NSDate   *timeStamp;
@property (strong,nonatomic) NSString *functionName;
@property (strong,nonatomic) NSString *infoMsg;

@end

@implementation DSLogRecord

- (id)initWithTimeStamp:(NSDate *)date functionName:(NSString *)name info:(NSString *)info {
    self = [super init];
    if (self) {
        _timeStamp = date;
        _functionName = name;
        _infoMsg = info;
    }
    return self;
}

- (void)setTimeStamp:(NSDate *)date functionName:(NSString *)name info:(NSString *)info {
    self.timeStamp = date;
    self.functionName = name;
    self.infoMsg = info;
}

static NSDateFormatter *timestampFormatter;

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        timestampFormatter = [[NSDateFormatter alloc] init];
        [timestampFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
        [timestampFormatter setDateFormat:@"HH:mm:ss.SSS"];
    });
}

- (NSString *)getLogRecordString {
    if (self.timeStamp) {
        NSMutableString *buf = [[NSMutableString alloc] initWithString:@"\n"];
        [buf appendString:[timestampFormatter stringFromDate:self.timeStamp]];
        [buf appendString:@" "];
        [buf appendString:self.functionName];
        [buf appendString:@"\n\t"];
        [buf appendString:self.infoMsg];
        
        self.infoMsg = buf;
        self.timeStamp = nil;
    }

    return self.infoMsg;
}

@end


#pragma mark -
#pragma mark DSLogger

#import "DSLogger.h"

#define DSLOGGER_CAPACITY	128u

@interface DSLogger ()

@property (strong,atomic,readwrite) NSDate *lastUpdatedAt;

@end

@implementation DSLogger {
    dispatch_queue_t serialQueue;

#ifdef DEBUG_MODE
	// Clustering
	NSDate *clusterStartDate;
	NSString *lastFunction;
#endif

	// Ring buffer
	NSMutableArray *buffer;
	unsigned int startIndex, count;
}

static DSLogger *sharedLogger = nil;

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
	if (!(self = [super init])) {
		return nil;
    }

#ifdef DEBUG_MODE
	// Clustering
	clusterStartDate = [NSDate distantPast];
	lastFunction = [[NSString alloc] init];
#endif

	buffer = [[NSMutableArray alloc] initWithCapacity:DSLOGGER_CAPACITY];
	startIndex = count = 0u;

    serialQueue = dispatch_queue_create("com.dustinrue.ControlPlane.DSLogger", DISPATCH_QUEUE_SERIAL);
    if (!serialQueue) {
        self = nil;
        return nil;
    }

    _lastUpdatedAt = [NSDate distantPast];
    
	return self;
}

- (void)dealloc {
    if (serialQueue) {
        //dispatch_release(serialQueue);
    }
}

- (void)logFromFunction:(NSString *)fnName withInfo:(NSString *)info {
    [[self class] logFromFunction:fnName withInfo:info];
}

+ (void)logFromFunction:(NSString *)fnName withInfo:(NSString *)info {
#ifdef DEBUG_MODE
	NSLog(@"%@ %@", fnName, info);
#endif

    NSDate *now = [[NSDate alloc] init];
    NSString *fnNameCopy = [fnName copy], *infoCopy = [info copy];

    dispatch_async(sharedLogger->serialQueue, ^{
        [sharedLogger doLogFromFunction:fnNameCopy withInfo:infoCopy timeStamp:now];
    });
}

- (void)doLogFromFunction:(NSString *)func withInfo:(NSString *)info timeStamp:(NSDate *)date {
#ifdef DEBUG_MODE
    // "Clustering" all adjacent records coming from the same function within a limited timeframe
	static const NSTimeInterval clusterThreshold = 0.5; // seconds

	if (([date timeIntervalSinceDate:clusterStartDate] < clusterThreshold) && [func isEqualToString:lastFunction]) {
		info = [@"\n\t" stringByAppendingString:info];
        date = nil;
    } else {
        clusterStartDate = date;
        lastFunction = func;
	}
#endif

    if (count < DSLOGGER_CAPACITY) {
        DSLogRecord *record = [[DSLogRecord alloc] initWithTimeStamp:date functionName:func info:info];
		[buffer addObject:record];

		++count;
	} else {
		[(DSLogRecord *)buffer[startIndex] setTimeStamp:date functionName:func info:info];

        ++startIndex;
        startIndex %= DSLOGGER_CAPACITY;
	}

    self.lastUpdatedAt = [[NSDate alloc] init]; // set to now
}

- (NSString *)buffer {
	NSMutableString *buf = [NSMutableString string];

    dispatch_suspend(serialQueue);

	unsigned int i = startIndex;
    for (unsigned int cnt = count; cnt > 0u; --cnt) {
        [buf appendString:[(DSLogRecord *) buffer[i] getLogRecordString]];

        ++i;
        i %= DSLOGGER_CAPACITY;
	}

    dispatch_resume(serialQueue);

	return buf;
}

@end
