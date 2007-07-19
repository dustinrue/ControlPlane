//
//  RunningApplicationEvidenceSource.h
//  MarcoPolo
//
//  Created by David Symonds on 23/5/07.
//

#import <Cocoa/Cocoa.h>
#import "GenericEvidenceSource.h"


@interface RunningApplicationEvidenceSource : GenericEvidenceSource {
	NSLock *lock;
	NSMutableArray *applications;
}

- (id)init;
- (void)dealloc;

- (void)start;
- (void)stop;

- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;

@end
