//
//  MonitorEvidenceSource.h
//  ControlPlane
//
//  Created by David Symonds on 2/07/07.
//

#import "GenericEvidenceSource.h"


@interface MonitorEvidenceSource : GenericEvidenceSource {
	NSLock *lock;
	NSMutableArray *monitors;
}

- (id)init;
- (void)dealloc;

- (void)doFullUpdate;
- (void)clearCollectedData;

- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;
- (void) start;
- (void) stop;

@end
