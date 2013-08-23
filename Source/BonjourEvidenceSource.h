//
//  BonjourEvidenceSource.h
//  ControlPlane
//
//  Created by David Symonds on 27/08/07.
//

#import "GenericEvidenceSource.h"
#import "CPBonjourResolver.h"

@interface BonjourEvidenceSource : GenericEvidenceSource<CPBonjourResolverDelegate,NSNetServiceDelegate>

- (id)init;
- (void)dealloc;

- (void)start;
- (void)stop;

- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;

@end
