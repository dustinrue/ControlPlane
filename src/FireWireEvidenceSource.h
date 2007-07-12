//
//  FireWireEvidenceSource.h
//  MarcoPolo
//
//  Created by David Symonds on 30/04/07.
//

#import <Cocoa/Cocoa.h>
#import "EvidenceSource.h"


@interface FireWireEvidenceSource : EvidenceSource {
	NSLock *lock;
	NSMutableArray *devices;

	IONotificationPortRef notificationPort;
	CFRunLoopSourceRef runLoopSource;
	io_iterator_t addedIterator, removedIterator;
}

- (id)init;
- (void)dealloc;

- (void)start;
- (void)stop;

- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSArray *)getSuggestions;

- (NSArray *)getDevices;

// Private
- (void)devAdded:(io_iterator_t)iterator;
- (void)devRemoved:(io_iterator_t)iterator;


@end
