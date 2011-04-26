//
//  MKPlacemark+Private.m
//  MapKit
//
//  Created by Rick Fillion on 7/26/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import "MKPlacemark+Private.h"

@interface MKPlacemark (ReallyPrivate)

- (CLLocationCoordinate2D)_coordinateFromGoogleGeocoderResult:(NSDictionary *)result;

@end


@implementation MKPlacemark (Private)

- (id)initWithGoogleGeocoderResult:(NSDictionary *)result
{
    if (self = [super init])
    {
	coordinate = [self _coordinateFromGoogleGeocoderResult:result];
        NSArray *components = [result objectForKey:@"address_components"];
        if (components)
        {
            for (NSDictionary *component in components)
            {
                NSString *longValue = [component objectForKey:@"long_name"];
                NSString *shortValue = [component objectForKey:@"short_name"];
                NSArray *types = [component objectForKey:@"types"];
                for (NSString *type in types)
                {
                    if ([type isEqualToString:@"street_number"])
                    {
                        thoroughfare = [longValue retain];
                    }
                    if ([type isEqualToString:@"route"])
                    {
                        NSString *newThoroughfare = [thoroughfare stringByAppendingFormat:@" %@", longValue];
                        [thoroughfare release];
                        thoroughfare = [newThoroughfare retain];
                    }
                    if ([type isEqualToString:@"locality"])
                    {
                        locality = [longValue retain];
                    }
                    if ([type isEqualToString:@"administrative_area_level_2"])
                    {
                        subAdministrativeArea = [longValue retain];
                    }
                    if ([type isEqualToString:@"administrative_area_level_1"])
                    {
                        administrativeArea = [shortValue retain];
                    }
                    if ([type isEqualToString:@"country"])
                    {
                        country = [longValue retain];
                        countryCode = [shortValue retain];
                    }
                }
            }
        }
        
    }
    return self;
}

#pragma mark -
#pragma mark Really Private

- (CLLocationCoordinate2D)_coordinateFromGoogleGeocoderResult:(NSDictionary *)result
{
    NSDictionary *location = [result valueForKeyPath:@"geometry.location"];
    NSArray *orderedKeys = [[location allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    NSString *latitudeKey = [orderedKeys objectAtIndex:0];
    NSString *longitudeKey = [orderedKeys objectAtIndex:1];
    NSNumber *latitude = [location objectForKey:latitudeKey];
    NSNumber *longitude = [location objectForKey:longitudeKey];
    CLLocationCoordinate2D aCoordinate;
    aCoordinate.latitude = [latitude doubleValue];
    aCoordinate.longitude = [longitude doubleValue];
    return aCoordinate;
}

@end
