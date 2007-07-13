//
//  MonitorEvidenceSource.h
//  MarcoPolo
//
//  Created by David Symonds on 2/07/07.
//

#import <Cocoa/Cocoa.h>
#import "EvidenceSource.h"


@interface MonitorEvidenceSource : LoopingEvidenceSource {
	NSLock *lock;
	NSMutableArray *monitors;
}

- (id)init;
- (void)dealloc;

- (void)doUpdate;
- (void)clearCollectedData;

- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;

@end
