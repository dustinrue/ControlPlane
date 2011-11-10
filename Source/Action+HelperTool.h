//
//  Action+HelperTool.h
//  ControlPlane
//
//  Created by David Jennes on 05/09/11.
//  Copyright 2011. All rights reserved.
//

#import "Action.h"
#import "CPHelperToolCommon.h"

@interface Action (HelperTool)

- (BOOL) helperToolPerformAction: (NSString *) action;
- (BOOL) helperToolPerformAction: (NSString *) action withParameter: (id) parameter;

@end
