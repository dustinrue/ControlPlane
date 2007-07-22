//
//  DSLogger.h
//  MarcoPolo
//
//  Created by David Symonds on 22/07/07.
//

#import <Cocoa/Cocoa.h>


@interface DSLogger : NSObject {
	NSLock *lock;
	NSDateFormatter *timestampFormatter;

	// Ring buffer
	NSMutableArray *buffer;
	int startIndex, count;
}

+ (DSLogger *)sharedLogger;

- (id)init;
- (void)dealloc;

- (void)logFromFunction:(const char *)function withFormat:(NSString *)format, ...;

- (NSString *)buffer;

#define DSLog(format, ...)	\
	[[DSLogger sharedLogger] logFromFunction:__PRETTY_FUNCTION__ withFormat:(format),##__VA_ARGS__]

@end