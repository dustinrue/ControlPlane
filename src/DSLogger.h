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

- (void)logWithFormat:(NSString *)format args:(va_list)args;

- (NSString *)buffer;

@end


void DSLog(NSString *format, ...);