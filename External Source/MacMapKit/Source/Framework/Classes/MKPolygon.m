//
//  MKPolygon.m
//  MapKit
//
//  Created by Rick Fillion on 7/15/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import "MKPolygon.h"

@interface MKPolygon (Private)

- (id)initWithCoordinates:(CLLocationCoordinate2D *)coords count:(NSUInteger)count;
- (id)initWithCoordinates:(CLLocationCoordinate2D *)coords count:(NSUInteger)count interiorPolygons:(NSArray *)interiorPolygons;

@end

@implementation MKPolygon

@synthesize interiorPolygons;

+ (MKPolygon *)polygonWithCoordinates:(CLLocationCoordinate2D *)coords count:(NSUInteger)count
{
    return [[[self alloc] initWithCoordinates:coords count:count] autorelease];
}

+ (MKPolygon *)polygonWithCoordinates:(CLLocationCoordinate2D *)coords count:(NSUInteger)count interiorPolygons:(NSArray *)interiorPolygons;
{
    return [[[self alloc] initWithCoordinates:coords count:count interiorPolygons:interiorPolygons] autorelease];
}

- (CLLocationCoordinate2D) coordinate
{
    return [super coordinate];
}

- (void)dealloc
{
    free(coordinates);
    [interiorPolygons release];
    [super dealloc];
}

#pragma mark Private

- (id)initWithCoordinates:(CLLocationCoordinate2D *)coords count:(NSUInteger)count
{
    if (self = [super init])
    {
        coordinates = malloc(sizeof(CLLocationCoordinate2D) * count);
        for (int i = 0; i < count; i++)
        {
            coordinates[i] = coords[i];
        }
        coordinateCount = count;
    }
    return self;
}

- (id)initWithCoordinates:(CLLocationCoordinate2D *)coords count:(NSUInteger)count interiorPolygons:(NSArray *)theInteriorPolygons
{
    if (self = [self initWithCoordinates:coords count:count])
    {
        interiorPolygons = [theInteriorPolygons retain];
    }
    return self;
}

@end
