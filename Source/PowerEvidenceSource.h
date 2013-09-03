//
//  PowerEvidenceSource.h
//  ControlPlane
//
//  Created by Mark Wallis on 30/4/07.
//  Minor updates done by Vladimir Beloborodov (VladimirTechMan) on 25 Aug 2013.
//

#import "GenericEvidenceSource.h"


@interface PowerEvidenceSource : GenericEvidenceSource

- (id)init;

- (void)start;
- (void)stop;

- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;

@end
