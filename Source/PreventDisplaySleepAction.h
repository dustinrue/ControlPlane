//
//  PreventDisplaySleepAction.h
//  ControlPlane
//
//  Created by Dustin Rue on 2/7/13.
//
//

#import "ToggleableAction.h"
#import <IOKit/pwr_mgt/IOPMLib.h>

@interface PreventDisplaySleepAction : ToggleableAction 

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;
+ (NSString *)helpText;
+ (NSString *)creationHelpText;

+ (NSArray *)limitedOptions;

@end

@interface PreventDisplaySleepActionStorage : NSObject

@property (assign) IOPMAssertionID assertionID;

+ (id) sharedStorage;

@end
