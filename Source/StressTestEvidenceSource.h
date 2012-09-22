//
//  StressTestEvidenceSource.h
//  ControlPlane
//
//  Created by Dustin Rue on 9/21/12.
//
//

#import "GenericEvidenceSource.h"

@interface StressTestEvidenceSource : GenericEvidenceSource {

}

@property (strong) NSTimer *loopTimer;

- (id)init;
- (void)dealloc;

- (void)start;
- (void)stop;

- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;
- (void) wtf:(NSTimer *) timer;

@end
