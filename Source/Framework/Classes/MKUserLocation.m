//
//  MKUserLocation.m
//  MapKit
//
//  Created by Rick Fillion on 7/11/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import "MKUserLocation.h"


@implementation MKUserLocation

@synthesize updating, location, title, subtitle;

- (void)dealloc
{
    [location release];
    [title release];
    [subtitle release];
    [super dealloc];
}

- (CLLocationCoordinate2D) coordinate
{
    return [location coordinate];
}

@end
