//
//  IPEvidenceSource.h
//  ControlPlane
//
//  Created by David Symonds on 29/03/07.
//  Modified by Dustin Rue on 27/08/11.
//

#import "EvidenceSource.h"
#import <SystemConfiguration/SystemConfiguration.h>


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

- (void)start;
- (void)stop;

- (NSMutableDictionary *)readFromPanel;
- (void)writeToPanel:(NSDictionary *)dict usingType:(NSString *)type;

- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;

@end
