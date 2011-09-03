//
//  FireWireEvidenceSource.h
//  ControlPlane
//
//  Created by David Symonds on 30/04/07.
//

#import "GenericLoopingEvidenceSource.h"


@interface FireWireEvidenceSource : GenericLoopingEvidenceSource {
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
