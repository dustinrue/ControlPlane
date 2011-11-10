//
//  DisplaySleepTime.h
//  ControlPlane
//
//  Created by Dustin Rue on 11/9/11.
//  Copyright (c) 2011. All rights reserved.
//


#import "Action.h"

@interface DisplaySleepTimeAction : Action <ActionWithLimitedOptions> {

    NSNumber *time;

}
- (id)initWithDictionary:(NSDictionary *)dict;
- (void)dealloc;
- (NSMutableDictionary *)dictionary;

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;
+ (NSString *)helpText;
+ (NSString *)creationHelpText;

+ (NSArray *)limitedOptions;
- (id)initWithOption:(NSString *)option;

@end

