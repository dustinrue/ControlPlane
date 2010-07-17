//
//  MKUserLocation.h
//  MapKit
//
//  Created by Rick Fillion on 7/11/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MapKit/MKAnnotation.h>

@class CLLocation;

@interface MKUserLocation : NSObject <MKAnnotation> {
    BOOL updating;
    CLLocation *location;
    NSString *title;
    NSString *subtitle;
}

// Returns YES if the user's location is being updated.
@property (readonly, nonatomic, getter=isUpdating) BOOL updating;

// Returns nil if the owning MKMapView's showsUserLocation is NO or the user's location has yet to be determined.
@property (readonly, nonatomic) CLLocation *location;

// The title to be displayed for the user location annotation.
@property (retain, nonatomic) NSString *title;

// The subtitle to be displayed for the user location annotation.
@property (retain, nonatomic) NSString *subtitle;


@end
