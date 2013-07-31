//
//  USBEvidenceSource.h
//  ControlPlane
//
//  Created by David Symonds on 29/03/07.
//

#import "GenericEvidenceSource.h"


@interface USBEvidenceSource : GenericEvidenceSource {
	NSLock *lock;
	NSMutableArray *devices;

	IONotificationPortRef notificationPort;
	CFRunLoopSourceRef runLoopSource;
	io_iterator_t addedIterator, removedIterator;
	BOOL paranoid;
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
