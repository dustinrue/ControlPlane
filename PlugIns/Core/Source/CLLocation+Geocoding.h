//
//  CLLocation+Geocoding.h
//  ControlPlane
//
//  Created by David Jennes on 26/09/11.
//  Copyright 2011. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>

@interface CLLocation (Geocoding)

// Address -> Location
+ (CLLocation *) geocode: (NSString **) address;

// Latitude, Longitude -> Address
+ (NSString *) reverseGeocodeLatitude: (CLLocationDegrees) latitude longitude: (CLLocationDegrees) longitude;

// Location -> Address
- (NSString *) reverseGeocode;

@end
