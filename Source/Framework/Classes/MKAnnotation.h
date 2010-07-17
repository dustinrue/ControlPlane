/*
 *  MKAnnotation.h
 *  MapKit
 *
 *  Created by Rick Fillion on 7/11/10.
 *  Copyright 2010 Centrix.ca. All rights reserved.
 *
 */

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@protocol MKAnnotation <NSObject>

// Center latitude and longitude of the annotion view.
@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;

@optional
// Title and subtitle for use by selection UI.
- (NSString *)title;
- (NSString *)subtitle;

@end
