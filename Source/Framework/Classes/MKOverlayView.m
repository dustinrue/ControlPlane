//
//  MKOverlayView.m
//  MapKit
//
//  Created by Rick Fillion on 7/12/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import "MKOverlayView.h"

@implementation MKOverlayView

@synthesize overlay;

- (id)initWithOverlay:(id <MKOverlay>)anOverlay
{
    if (self = [super init])
    {
        overlay = [anOverlay retain];
    }
    return self;
}


- (void)dealloc
{
    [overlay release];
    [super dealloc];
}



@end
