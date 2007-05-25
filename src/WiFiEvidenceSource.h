//
//  WiFiEvidenceSource.h
//  MarcoPolo
//
//  Created by David Symonds on 29/03/07.
//

#import <Cocoa/Cocoa.h>
#import "EvidenceSource.h"


@interface WiFiEvidenceSource : EvidenceSource {
	NSLock *lock;
	NSMutableArray *apList;
}

- (id)init;
- (void)dealloc;

- (void)doUpdate;
- (NSString *)name;
- (NSArray *)typesOfRulesMatched;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;

@end
