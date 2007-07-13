//
//  WiFiEvidenceSource.h
//  MarcoPolo
//
//  Created by David Symonds on 29/03/07.
//

#import <Cocoa/Cocoa.h>
#import "EvidenceSource.h"


@interface WiFiEvidenceSource : LoopingEvidenceSource {
	NSLock *lock;
	NSMutableArray *apList;
	int wakeUpCounter;
}

- (id)init;
- (void)dealloc;

- (void)wakeFromSleep:(id)arg;

- (void)doUpdate;
- (void)clearCollectedData;

- (NSString *)name;
- (NSArray *)typesOfRulesMatched;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;

@end
