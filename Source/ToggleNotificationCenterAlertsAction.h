//
//  ToggleNotificationCenterAlertsAction.h
//  ControlPlane
//
//  Created by Dustin Rue on 8/13/12.
//
//

#import "ToggleableAction.h"

@interface ToggleNotificationCenterAlertsAction : ToggleableAction

- (NSString *) description;
- (BOOL) execute: (NSString **) errorString;
+ (NSString *) helpText;
+ (NSString *) creationHelpText;

@end
