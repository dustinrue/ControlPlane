//
//  ToggleableAction.h
//  ControlPlane
//
//  Created by David Symonds on 7/06/07.
//

#import "CAction.h"


@interface ToggleableAction : CAction <ActionWithLimitedOptions> {
	BOOL turnOn;
}

- (id)initWithDictionary:(NSDictionary *)dict;
- (void)dealloc;
- (NSMutableDictionary *)dictionary;

+ (NSArray *)limitedOptions;
- (id)initWithOption:(NSNumber *)option;

@end
