//
//  ToggleableActionPlugin.h
//  ControlPlane
//
//  Created by Dustin Rue on 8/10/12.
//
//

#import <Foundation/Foundation.h>
#import "ActionPlugin.h"

@protocol ToggleableAction <Action,ActionWithLimitedOptions>

@property (assign) BOOL turnOn;

- (id)initWithDictionary:(NSDictionary *)dict;
- (void)dealloc;
- (NSMutableDictionary *)dictionary;

+ (NSArray *)limitedOptions;
- (id)initWithOption:(NSNumber *)option;

@end
