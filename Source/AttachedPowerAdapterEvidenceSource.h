//
//  AttachedPowerAdapterEvidenceSource.h
//  ControlPlane
//
//  Created by Dustin Rue on 8/27/12.
//
//

#import "GenericEvidenceSource.h"

@interface AttachedPowerAdapterEvidenceSource : GenericEvidenceSource {
    NSLock *lock;
}

@property (strong) NSNumber *attachedPowerAdapter;

- (id)init;
- (void)dealloc;

- (void)start;
- (void)stop;

- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;
@end
