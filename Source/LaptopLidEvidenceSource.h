//
//  LaptopLidEvidenceSource.m
//  ControlPlane
//
//  Created by Vladimir Beloborodov on July 15, 2013.
//  Modified by Vladimir Beloborodov on August 05, 2013.
//

#import "GenericEvidenceSource.h"

@interface LaptopLidEvidenceSource : GenericEvidenceSource


- (id)init;
- (void)dealloc;

- (void)start;
- (void)stop;

- (void)goingToSleep:(NSNotification*)note;

- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;

@end
