//
//  IPv6RuleType.h
//  ControlPlane
//
//  Created by VladimirTechMan on 19 Apr 2013.
//
//

#import "RuleType.h"

@interface IPv6RuleType : RuleType

+ (NSString *)panelNibName;
- (NSString *)name;

- (BOOL)doesRuleMatch:(NSMutableDictionary *)rule;

- (BOOL)validatePanelParams;
- (void)readFromPanelInto:(NSMutableDictionary *)rule;
- (NSString *)getDefaultDescription:(NSDictionary *)rule;
- (void)writeToPanel:(NSDictionary *)rule;

@end
