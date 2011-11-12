//
//  CLLocation+Geocoding.m
//  ControlPlane
//
//  Created by David Jennes on 26/09/11.
//  Copyright 2011. All rights reserved.
//

#import "CLLocation+Geocoding.h"
#import "JSONKit.h"

@implementation CLLocation (Geocoding)

static const NSString *kGoogleAPIPrefix = @"https://maps.googleapis.com/maps/api/geocode/json?";

+ (CLLocation *) geocode: (NSString **) address {
	NSString *param = [*address stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
	NSString *url = [NSString stringWithFormat: @"%@address=%@&sensor=false", kGoogleAPIPrefix, param];
	
	// fetch and parse response
	NSData *jsonData = [NSData dataWithContentsOfURL: [NSURL URLWithString: url]];
	if (!jsonData)
		return nil;
	NSDictionary *data = [[JSONDecoder decoder] objectWithData: jsonData];
	
	// check response status
	if (![[data objectForKey: @"status"] isEqualToString: @"OK"])
		return nil;
	
	// check number of results
	if ([[data objectForKey: @"results"] count] == 0)
		return nil;
	NSDictionary *result = [[data objectForKey: @"results"] objectAtIndex: 0];
	
	*address = [[result objectForKey: @"formatted_address"] copy];
	double lat = [[[[result objectForKey: @"geometry"] objectForKey: @"location"] objectForKey: @"lat"] doubleValue];
	double lng = [[[[result objectForKey: @"geometry"] objectForKey: @"location"] objectForKey: @"lng"] doubleValue];
	
	// create location
	return [[CLLocation alloc] initWithLatitude: lat longitude: lng];
}

+ (NSString *) reverseGeocodeLatitude: (CLLocationDegrees) latitude
			   longitude: (CLLocationDegrees) longitude {
	
	CLLocation *loc = [[CLLocation alloc] initWithLatitude: latitude longitude: longitude];
	
	return [loc reverseGeocode];
}

- (NSString *) reverseGeocode {
	NSString *url = [NSString stringWithFormat: @"%@latlng=%f,%f&sensor=false",
					 kGoogleAPIPrefix, self.coordinate.latitude, self.coordinate.longitude];
	
	// fetch and parse response
	NSData *jsonData = [NSData dataWithContentsOfURL: [NSURL URLWithString: url]];
	if (!jsonData)
		return nil;
	NSDictionary *data = [[JSONDecoder decoder] objectWithData: jsonData];
	
	// check response status
	if (![[data objectForKey: @"status"] isEqualToString: @"OK"])
		return nil;
	
	// check number of results
	NSArray *results = [data objectForKey: @"results"];
	if ([results count] == 0)
		return nil;
	
	// get result
	NSString *result = [[results objectAtIndex: 0] objectForKey: @"formatted_address"];
	return [result copy];
}

@end
