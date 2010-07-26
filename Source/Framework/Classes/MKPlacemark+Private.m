//
//  MKPlacemark+Private.m
//  MapKit
//
//  Created by Rick Fillion on 7/26/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import "MKPlacemark+Private.h"

@implementation MKPlacemark (Private)

- (id)initWithGoogleGeocoderResult:(NSDictionary *)result
{
    if (self = [super init])
    {
        coordinate.latitude = [[result valueForKeyPath:@"geometry.location.b"] doubleValue];
        coordinate.longitude = [[result valueForKeyPath:@"geometry.location.c"] doubleValue];
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

@end
