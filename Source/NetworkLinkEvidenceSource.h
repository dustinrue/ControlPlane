//
//  NetworkLinkEvidenceSource.h
//  ControlPlane
//
//  Created by Mark Wallis on 25/7/07.
//

#import <Cocoa/Cocoa.h>
#include <SystemConfiguration/SystemConfiguration.h>
#import "GenericEvidenceSource.h"


@interface NetworkLinkEvidenceSource : GenericEvidenceSource {
	NSLock *lock;
	NSMutableArray *interfaces;

	// For SystemConfiguration asynchronous notifications
	SCDynamicStoreRef store;
	CFRunLoopSourceRef runLoop;
}

- (id)init;
- (void)dealloc;

- (void)doFullUpdate:(id)sender;

- (void)start;
- (void)stop;

- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;

@end
