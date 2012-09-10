//
//  ActiveApplicationEvidenceSource.h
//  ControlPlane
//
//  Created by Dustin Rue on 8/13/12.
//
//

#import "GenericEvidenceSource.h"

@interface ActiveApplicationEvidenceSource : GenericEvidenceSource {
    NSLock *lock;
}

@property (retain) NSString *activeApplication;

- (id)init;
- (void)dealloc;

- (void)start;
- (void)stop;

- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;

@end
