//
//  IPv4RuleType.h
//  ControlPlane
//
//  Created by VladimirTechMan on 18 Apr 2013.
//
//

#import "RuleType.h"

@interface IPv4RuleType : RuleType

+ (NSString *)panelNibName;
- (NSString *)name;

- (BOOL)doesRuleMatch:(NSMutableDictionary *)rule;

- (BOOL)validatePanelParams;
- (void)readFromPanelInto:(NSMutableDictionary *)rule;
- (NSString *)getDefaultDescription:(NSDictionary *)rule;
- (void)writeToPanel:(NSDictionary *)rule;

@end
