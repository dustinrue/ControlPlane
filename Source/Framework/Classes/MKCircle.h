//
//  MKCircle.h
//  MapPrototype
//
//  Created by Rick Fillion on 7/12/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreLocation/CoreLocation.h>
#import "MKShape.h"
#import "MKOverlay.h"
#import "MKGeometry.h"

@interface MKCircle : MKShape <MKOverlay> {
    CLLocationDistance radius;
}

+ (MKCircle *)circleWithCenterCoordinate:(CLLocationCoordinate2D)coord radius:(CLLocationDistance)radius;

@property (nonatomic, readonly) CLLocationDistance radius;
@property (nonatomic, readonly) MKCoordinateRegion region;

@end
