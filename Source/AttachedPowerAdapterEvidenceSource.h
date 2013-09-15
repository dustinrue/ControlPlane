//
//  AttachedPowerAdapterEvidenceSource.h
//  ControlPlane
//
//  Created by Dustin Rue on 8/27/12.
//
//

#import "GenericEvidenceSource.h"

@interface AttachedPowerAdapterEvidenceSource : GenericEvidenceSource

- (void)start;
- (void)stop;

- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;

@end
