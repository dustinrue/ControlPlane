//
//  NetworkLocationAction.h
//  ControlPlane
//
//  Created by David Symonds on 4/07/07.
//  Modified by Vladimir Beloborodov (VladimirTechMan) on 12 June 2013.
//

#import "Action.h"


@interface NetworkLocationAction : Action <ActionWithLimitedOptions> {
	NSString *networkLocation;
}

- (id)initWithOption:(NSString *)option;
- (id)init;
- (id)initWithDictionary:(NSDictionary *)dict;

- (NSMutableDictionary *)dictionary;

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;
+ (NSString *)helpText;
+ (NSString *)creationHelpText;

+ (NSArray *)limitedOptions;

@end
