//
//  ServerAddressRuleType.h
//  ControlPlane
//
//  Created by VladimirTechMan on 03/03/2013.
//
//

#import "RuleType.h"

@interface ServerAddressRuleType : RuleType

+ (NSString *)panelNibName;

- (NSString *)name;

- (BOOL)doesRuleMatch:(NSDictionary *)rule;

- (BOOL)validatePanelParams;
- (void)readFromPanelInto:(NSMutableDictionary *)rule;
- (NSString *)getDefaultDescription:(NSDictionary *)rule;
- (void)writeToPanel:(NSDictionary *)rule;

@end
