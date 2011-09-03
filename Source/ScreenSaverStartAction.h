//
//  ScreenSaverStartAction.h
//  ControlPlane
//
//  Created by David Symonds on 4/11/07.
//

#import "ToggleableAction.h"


@interface ScreenSaverStartAction : ToggleableAction {
}

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;
+ (NSString *)helpText;
+ (NSString *)creationHelpText;

+ (NSArray *)limitedOptions;

@end
