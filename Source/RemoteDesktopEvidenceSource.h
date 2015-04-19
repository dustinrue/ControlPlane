//
//  RemoteDesktopEvidenceSource.h
//  ControlPlane
//
//  Created by Dustin Rue on 4/19/15.
//
//

#import "GenericEvidenceSource.h"

@interface RemoteDesktopEvidenceSource : GenericEvidenceSource
@property BOOL userConnected;

- (id)init;

- (void)start;
- (void)stop;

- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;
@end
