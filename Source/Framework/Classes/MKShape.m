//
//  MKShape.m
//  MapPrototype
//
//  Created by Rick Fillion on 7/12/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import "MKShape.h"


@implementation MKShape

@synthesize title, subtitle, coordinate;

- (void)dealloc
{
    [title release];
    [subtitle release];
    [super dealloc];
}

@end
