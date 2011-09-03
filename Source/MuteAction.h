//
//  MuteAction.h
//  ControlPlane
//
//  Created by David Symonds on 7/06/07.
//

#import "ToggleableAction.h"


@interface MuteAction : ToggleableAction {
}

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;
+ (NSString *)helpText;
+ (NSString *)creationHelpText;

+ (NSArray *)limitedOptions;

@end
