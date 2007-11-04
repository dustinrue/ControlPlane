//
//  ScreenSaverStartAction.h
//  MarcoPolo
//
//  Created by David Symonds on 4/11/07.
//

#import <Cocoa/Cocoa.h>
#import "ToggleableAction.h"


@interface ScreenSaverStartAction : ToggleableAction {
}

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;
+ (NSString *)helpText;
+ (NSString *)creationHelpText;

+ (NSArray *)limitedOptions;

@end
