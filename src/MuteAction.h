//
//  MuteAction.h
//  MarcoPolo
//
//  Created by David Symonds on 7/06/07.
//

#import <Cocoa/Cocoa.h>
#import "ToggleableAction.h"


@interface MuteAction : ToggleableAction <ActionWithLimitedOptions> {
}

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;
+ (NSString *)helpText;
+ (NSString *)creationHelpText;

+ (NSArray *)limitedOptions;
- (id)initWithOption:(NSString *)option;

@end
