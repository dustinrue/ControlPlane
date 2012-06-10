//
//  NSMutableArray+Merge.h
//  ControlPlane
//
//  Created by Dustin Rue on 5/28/12.
//  Copyright (c) 2012 ControlPlane. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableArray (Merge)

- (BOOL) mergeWith:(NSArray *) incomingArray;

@end
