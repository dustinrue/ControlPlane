//
//  VPNAction.h
//  ControlPlane
//
//  Created by Mark Wallis on 18/07/07.
//

#import "Action.h"


@interface VPNAction : Action <ActionWithLimitedOptions> {
	NSString *vpnType;
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
