//
//  LightEvidenceSource.h
//  MarcoPolo
//
//  Created by Rodrigo Damazio on 09/07/07.
//

#import <Cocoa/Cocoa.h>
#import <IOKit/IOTypes.h>
#import "EvidenceSource.h"

@interface LightEvidenceSource : LoopingEvidenceSource {
	NSLock *lock;
	io_connect_t ioPort;
	int leftLight, rightLight;
	NSArray *suggestions;
}

- (id)init;
- (void)dealloc;

- (void)doUpdate;
- (void)clearCollectedData;

- (NSString *)name;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSArray *)getSuggestions;

- (void)initSuggestions;	// internal

@end
