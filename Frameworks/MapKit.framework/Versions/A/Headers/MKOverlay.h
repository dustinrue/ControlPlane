/*
 *  MKOverlay.h
 *  MapKit
 *
 *  Created by Rick Fillion on 7/12/10.
 *  Copyright 2010 Centrix.ca. All rights reserved.
 *
 */

#import <MapKit/MKAnnotation.h>
#import <MapKit/MKTypes.h>
#import <MapKit/MKGeometry.h>


@protocol MKOverlay <MKAnnotation>

@required

// From MKAnnotation, for areas this should return the centroid of the area.
@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;

@end
