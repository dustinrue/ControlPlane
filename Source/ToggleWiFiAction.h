//
//  ToggleWiFiAction.h
//  ControlPlane
//
//  Created by David Symonds on 3/04/07.
//

#import "ToggleableAction.h"


@interface ToggleWiFiAction : ToggleableAction {
}

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;
+ (NSString *)helpText;
+ (NSString *)creationHelpText;

@end
