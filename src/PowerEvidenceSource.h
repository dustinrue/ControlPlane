//
//  PowerEvidenceSource.h
//  MarcoPolo
//
//  Created by Mark Wallis <marcopolo@markwallis.id.au> on 30/4/07.
//

#import <Cocoa/Cocoa.h>
#import "EvidenceSourceWithCustomPanel.h"


@interface PowerEvidenceSource : EvidenceSourceWithCustomPanel {
	NSString *status;
	CFRunLoopSourceRef runLoopSource;

	// For custom panel
	NSNumber *batteryChosen;
}

- (id)init;

- (void)doFullUpdate;	// internal

- (void)start;
- (void)stop;

- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;

- (NSMutableDictionary *)readFromPanel;
- (void)writeToPanel:(NSDictionary *)dict usingType:(NSString *)type;

@end
