//
//  BonjourEvidenceSource.h
//  MarcoPolo
//
//  Created by David Symonds on 27/08/07.
//

#import <Cocoa/Cocoa.h>
#import "GenericEvidenceSource.h"


@interface BonjourEvidenceSource : GenericEvidenceSource {
	NSLock *lock;
	NSMutableArray *services;
	NSNetServiceBrowser *browser;
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
