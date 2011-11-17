//
//  AdiumAction.h
//  ControlPlane
//
//  Created by Dustin Rue on 11/16/11.
//  Copyright (c) 2011. All rights reserved.
//

#import "Action.h"

@interface AdiumAction : Action <ActionWithString> {
	NSString *status;
}

- (id)initWithDictionary:(NSDictionary *)dict;
- (void)dealloc;
- (NSMutableDictionary *)dictionary;

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;
+ (NSString *)helpText;
+ (NSString *)creationHelpText;

@end