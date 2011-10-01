//
//  ScreenSaverTimeAction.h
//  ControlPlane
//
//  Created by David Symonds on 7/16/07.
//

#import "CAction.h"


@interface ScreenSaverTimeAction : CAction <ActionWithLimitedOptions> {
	NSNumber *time;
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
