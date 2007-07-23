//
//  IPEvidenceSource.h
//  MarcoPolo
//
//  Created by David Symonds on 29/03/07.
//

#import <Cocoa/Cocoa.h>
#include <SystemConfiguration/SystemConfiguration.h>
#import "EvidenceSource.h"


@interface IPEvidenceSource : EvidenceSource {
	NSLock *lock;
	NSMutableArray *addresses;

	// For SystemConfiguration asynchronous notifications
	SCDynamicStoreRef store;
	CFRunLoopSourceRef runLoop;

	// For custom panel
	IBOutlet NSComboBox *ruleComboBox;
	NSString *ruleIP;
	NSString *ruleNetmask;
}

- (id)init;
- (void)dealloc;

- (void)doFullUpdate:(id)sender;

- (void)start;
- (void)stop;

- (NSMutableDictionary *)readFromPanel;
- (void)writeToPanel:(NSDictionary *)dict usingType:(NSString *)type;

- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;

@end
