//
//  USBEvidenceSource.h
//  MarcoPolo
//
//  Created by David Symonds on 29/03/07.
//

#import <Cocoa/Cocoa.h>
#import "GenericLoopingEvidenceSource.h"


@interface USBEvidenceSource : GenericLoopingEvidenceSource {
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

- (void)doUpdate;
- (void)clearCollectedData;

- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;

- (NSArray *)getDevices;

@end
