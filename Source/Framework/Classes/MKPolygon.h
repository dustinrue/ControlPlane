//
//  MKPolygon.h
//  MapPrototype
//
//  Created by Rick Fillion on 7/15/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MKMultiPoint.h"
#import "MKOverlay.h"

@interface MKPolygon : MKMultiPoint <MKOverlay> {
    NSArray *interiorPolygons;
}

@property (readonly) NSArray *interiorPolygons;

+ (MKPolygon *)polygonWithCoordinates:(CLLocationCoordinate2D *)coords count:(NSUInteger)count;
+ (MKPolygon *)polygonWithCoordinates:(CLLocationCoordinate2D *)coords count:(NSUInteger)count interiorPolygons:(NSArray *)interiorPolygons;


@end

