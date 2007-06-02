//
//  USBEvidenceSource.h
//  MarcoPolo
//
//  Created by David Symonds on 29/03/07.
//

#import <Cocoa/Cocoa.h>
#import "EvidenceSource.h"


@interface USBEvidenceSource : EvidenceSource <EvidenceSourceThatGrowls> {
	NSLock *lock;
	NSMutableArray *devices;

	IONotificationPortRef notificationPort;
	CFRunLoopSourceRef runLoopSource;
	io_iterator_t addedIterator, removedIterator;

	BOOL shouldGrowl;
	id growlDelegate;
}

- (id)init;
- (void)dealloc;

- (void)doUpdate;
- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSArray *)getSuggestions;

- (NSArray *)getDevices;

// Private
- (void)devAdded:(io_iterator_t)iterator;
- (void)devRemoved:(io_iterator_t)iterator;

- (BOOL)growls;
- (void)setGrowls:(BOOL)growls;
- (void)setGrowlDelegate:(id)delegate;

@end
