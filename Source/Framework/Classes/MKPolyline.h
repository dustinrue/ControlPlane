//
//  MKPolyline.h
//  MapPrototype
//
//  Created by Rick Fillion on 7/15/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MKMultiPoint.h"
#import "MKOverlay.h"

@interface MKPolyline : MKMultiPoint <MKOverlay>

+ (MKPolyline *)polylineWithCoordinates:(CLLocationCoordinate2D *)coords count:(NSUInteger)count;

@end

