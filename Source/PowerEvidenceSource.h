//
//  PowerEvidenceSource.h
//  ControlPlane
//
//  Created by Mark Wallis on 30/4/07.
//

#import "GenericEvidenceSource.h"


@interface PowerEvidenceSource : GenericEvidenceSource {
	NSString *status;
}

- (id)init;

- (void)start;
- (void)stop;

- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;

@end
