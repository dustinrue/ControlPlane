//
//  ToggleableAction.h
//  MarcoPolo
//
//  Created by David Symonds on 7/06/07.
//

#import <Cocoa/Cocoa.h>
#import "Action.h"


@interface ToggleableAction : Action {
	BOOL turnOn;
}

- (id)initWithDictionary:(NSDictionary *)dict;
- (void)dealloc;
- (NSMutableDictionary *)dictionary;

+ (NSArray *)limitedOptions;
- (id)initWithOption:(NSString *)option;

@end
