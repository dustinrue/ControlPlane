//
//  PowerEvidenceSource.h
//  MarcoPolo
//
//  Created by Mark Wallis <marcopolo@markwallis.id.au> on 30/4/07.
//

#import <Cocoa/Cocoa.h>
#import "EvidenceSource.h"


@interface PowerEvidenceSource : EvidenceSource {
	NSLock *lock;
	NSString *status;
}

- (id)init;
- (void)dealloc;

- (void)doUpdate;
- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;

@end
