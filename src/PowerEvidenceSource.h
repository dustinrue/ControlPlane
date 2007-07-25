//
//  PowerEvidenceSource.h
//  MarcoPolo
//
//  Created by Mark Wallis on 30/4/07.
//

#import <Cocoa/Cocoa.h>
#import "GenericEvidenceSource.h"


@interface PowerEvidenceSource : GenericEvidenceSource {
	NSString *status;
	CFRunLoopSourceRef runLoopSource;
}

- (id)init;

- (void)start;
- (void)stop;

- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;

@end
