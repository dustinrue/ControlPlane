//
//  FirewallRuleAction.h
//  ControlPlane
//
//  Created by Mark Wallis on 17/07/07.
//

#import "Action.h"


@interface FirewallRuleAction : Action <ActionWithLimitedOptions> {
	NSString *ruleName;
}

- (id)initWithDictionary:(NSDictionary *)dict;
- (void)dealloc;
- (NSMutableDictionary *)dictionary;

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;
+ (NSString *)helpText;
+ (NSString *)creationHelpText;

+ (NSArray *)limitedOptions;
- (id)initWithOption:(NSString *)option;

@end
