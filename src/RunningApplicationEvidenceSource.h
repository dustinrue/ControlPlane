//
//  RunningApplicationEvidenceSource.h
//  MarcoPolo
//
//  Created by David Symonds on 23/5/07.
//

#import <Cocoa/Cocoa.h>
#import "EvidenceSource.h"


@interface RunningApplicationEvidenceSource : EvidenceSource {
	NSLock *lock;
	NSMutableArray *applications;
}

- (id)init;
- (void)dealloc;

- (void)doUpdate;
- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;

@end
