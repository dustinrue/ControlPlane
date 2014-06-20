//
//  PreventSystemSleepAction.h
//  ControlPlane
//
//  Created by Dustin Rue on 6/19/14.
//
//

#import "ToggleableAction.h"
#import <IOKit/pwr_mgt/IOPMLib.h>

@interface PreventSystemSleepAction : ToggleableAction

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;
+ (NSString *)helpText;
+ (NSString *)creationHelpText;

+ (NSArray *)limitedOptions;

@end

@interface PreventSystemSleepActionStorage : NSObject

@property (assign) IOPMAssertionID assertionID;

+ (id) sharedStorage;

@end
