//
//  MKPlacemark.h
//  MapKit
//
//  Created by Rick Fillion on 7/24/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MapKit/MKAnnotation.h>
#import <CoreLocation/CLLocation.h>

@interface MKPlacemark : NSObject <MKAnnotation> {
    CLLocationCoordinate2D coordinate;
    NSDictionary *addressDictionary;
    NSString *thoroughfare;
    NSString *subThoroughfare;
    NSString *locality;
    NSString *subLocality;
    NSString *administrativeArea;
    NSString *subAdministrativeArea;
    NSString *postalCode;
    NSString *country;
    NSString *countryCode;
}

// An address dictionary is a dictionary in the same form as returned by 
// ABRecordCopyValue(person, kABPersonAddressProperty).
- (id)initWithCoordinate:(CLLocationCoordinate2D)coordinate
       addressDictionary:(NSDictionary *)addressDictionary;

@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;

// Can be turned into a formatted address with ABCreateStringWithAddressDictionary.
@property (nonatomic, readonly) NSDictionary *addressDictionary;

@property (nonatomic, readonly) NSString *thoroughfare; // street address, eg 1 Infinite Loop
@property (nonatomic, readonly) NSString *subThoroughfare;
@property (nonatomic, readonly) NSString *locality; // city, eg. Cupertino
@property (nonatomic, readonly) NSString *subLocality; // neighborhood, landmark, common name, etc
@property (nonatomic, readonly) NSString *administrativeArea; // state, eg. CA
@property (nonatomic, readonly) NSString *subAdministrativeArea; // county, eg. Santa Clara
@property (nonatomic, readonly) NSString *postalCode; // zip code, eg 95014
@property (nonatomic, readonly) NSString *country; // eg. United States
@property (nonatomic, readonly) NSString *countryCode; // eg. US

@end
