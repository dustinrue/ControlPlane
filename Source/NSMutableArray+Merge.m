//
//  NSMutableArray+Merge.m
//  ControlPlane
//
//  Created by Dustin Rue on 5/28/12.
//  Copyright (c) 2012 ControlPlane. All rights reserved.
//

#import "NSMutableArray+Merge.h"

@implementation NSMutableArray (Merge)

- (BOOL) mergeWith:(NSArray *) incomingArray {
    
    //NSLog(@"before %@", self);
    BOOL madeChanges = NO;
    
    // can't edit self while enumerating it
    // so we enumerate a copy
    NSMutableArray *tmp = [self copy];
    
    // walk incoming array and see if the item exists
    // in self, if it doesn't then we add that item
    for (id item in incomingArray) {
        if ((int)[tmp indexOfObject:item] == -1) {
            madeChanges = YES;
            [self addObject:item];
        }
    }
    
    // walk the self array and remove anything that
    // exists in self but not in incoming
    for (id item in tmp) {
        if ((int)[incomingArray indexOfObject:item] == -1) {
            madeChanges = YES;
            [self removeObject:item];
        }
    }
    [tmp release];
    
    //NSLog(@"after %@", self);
    return madeChanges;
}

@end
