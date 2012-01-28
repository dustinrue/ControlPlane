//
//  TimeMachineDestinationAction.h
//  ControlPlane
//
//  Created by Dustin Rue on 1/23/12.
//  Copyright (c) 2012 ControlPlane. All rights reserved.
//

#import "Action.h"




@interface TimeMachineDestinationAction : Action <ActionWithLimitedOptions> {
    NSDictionary *destinationVolumePath;
}

@property (retain) NSDictionary *destinationVolumePath;

- (id) initWithDictionary: (NSDictionary *) dict;
- (void) dealloc;
- (NSMutableDictionary *) dictionary;

- (NSString *) description;
- (BOOL) execute: (NSString **) errorString;
+ (NSString *) helpText;
+ (NSString *) creationHelpText;

+ (NSArray *) limitedOptions;
- (id) initWithOption: (NSString *) option;

- (void) didReceiveNotificationResponse:(NSNotification *) notification;

@end