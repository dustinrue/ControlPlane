//
//  MKCircle.m
//  MapKit
//
//  Created by Rick Fillion on 7/12/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import "MKCircle.h"

@interface MKCircle (Private)

- (id)initWithCenterCoordinate:(CLLocationCoordinate2D)aCoord radius:(CLLocationDistance)aRadius;

@end


@implementation MKCircle

@synthesize coordinate, radius;

+ (MKCircle *)circleWithCenterCoordinate:(CLLocationCoordinate2D)aCoord radius:(CLLocationDistance)aRadius
{
    return [[[self alloc] initWithCenterCoordinate:aCoord radius:aRadius] autorelease];
}


- (MKCoordinateRegion)region
{
    MKCoordinateRegion theRegion;
    theRegion.center = [self coordinate];
    CGFloat latitudeDelta =  [self radius] / (111 * 1000);  // 111km per degree latitude
    theRegion.span.latitudeDelta = latitudeDelta;
    theRegion.span.longitudeDelta = latitudeDelta;   // assume we're at the equator, it'll make our lives easier, and chances are we're dealing with small circles
    return theRegion;
}

#pragma mark Private

- (id)initWithCenterCoordinate:(CLLocationCoordinate2D)aCoord radius:(CLLocationDistance)aRadius
{
    if (self = [super init])
    {
        coordinate = aCoord;
        radius = aRadius;
    }
    return self;
}

@end
