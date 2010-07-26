//
//  MKPlacemark.m
//  MapKit
//
//  Created by Rick Fillion on 7/24/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import "MKPlacemark.h"


@implementation MKPlacemark

@synthesize coordinate;
@synthesize addressDictionary;
@synthesize thoroughfare;
@synthesize subThoroughfare;
@synthesize locality;
@synthesize subLocality;
@synthesize administrativeArea;
@synthesize subAdministrativeArea;
@synthesize postalCode;
@synthesize country;
@synthesize countryCode;

- (id)initWithCoordinate:(CLLocationCoordinate2D)aCoordinate
       addressDictionary:(NSDictionary *)anAddressDictionary
{
    if (self = [super init])
    {
        coordinate = aCoordinate;
        addressDictionary = [anAddressDictionary retain];        
    }
    return self;
}

- (void)dealloc
{
    [addressDictionary release];
    [thoroughfare release];
    [subThoroughfare release];
    [locality release];
    [subLocality release];
    [administrativeArea release];
    [subAdministrativeArea release];
    [postalCode release];
    [country release];
    [countryCode release];
    [super dealloc];
}

- (NSString *)description
{
    NSString *superDescription = [super description];
    return [superDescription stringByAppendingFormat:
            @" (%f, %f) {thoroughfare: %@,\n subThoroughfare: %@,\n locality: %@,\n subLocality: %@,\n administrativeArea: %@,\n subAdministrativeArea: %@,\n postalCode: %@,\n country: %@,\n countryCode: %@\n}",
            coordinate.latitude, coordinate.longitude, thoroughfare, subThoroughfare, locality, subLocality, administrativeArea, subAdministrativeArea, postalCode, country, countryCode];
}

@end
