//
//  ScreenLockEvidenceSource.h
//  ControlPlane
//
//  Created by Roman Shevtsov on 12/12/15.
//
//

#import "GenericEvidenceSource.h"

@interface ScreenLockEvidenceSource : GenericEvidenceSource

- (id) init;

- (void) doRealUpdate;

- (void) start;
- (void) stop;

- (NSString*) name;
- (BOOL) doesRuleMatch: (NSDictionary*) rule;
- (NSString*) getSuggestionLeadText: (NSString*) type;
- (NSArray*) getSuggestions;

@end
