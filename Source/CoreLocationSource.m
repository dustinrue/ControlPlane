//
//	CoreLocationSource.m
//	ControlPlane
//
//	Created by David Jennes on 03/09/11.
//	Copyright 2011. All rights reserved.
//

#import "CoreLocationSource.h"
#import "DSLogger.h"
#import "JSONKit.h"

@interface CoreLocationSource (Private)

- (void) updateMap;
+ (BOOL) geocodeAddress: (NSString **) address toLatitude: (double*) latitude andLongitude: (double*) longitude;
+ (NSString *) reverseGeocodeWithLatitude: (double) latitude andLongitude: (double) longitude;
+ (BOOL) stringToCoordinates: (in NSString *) text toLatitude: (out double*) latitude andLongitude: (out double*) longitude;

@end

@implementation CoreLocationSource

static const NSString *kGoogleAPIPrefix = @"https://maps.googleapis.com/maps/api/geocode/json?";

- (id) init {
    self = [super initWithNibNamed:@"CoreLocationRule"];
    if (!self)
        return nil;
    
	locationManager = [[CLLocationManager alloc] init];
	locationManager.delegate = self;
	current = locationManager.location;
	
	address = @"";
	coordinates = @"0.0, 0.0";
	accuracy = @"0 m";
	
    return self;
}

- (void) dealloc {
	[locationManager stopUpdatingLocation];
	[locationManager release];
	
	[super dealloc];
}

- (void) start {
	if (running)
		return;
	
	[locationManager startUpdatingLocation];
	
	running = YES;
}

- (void) stop {
	if (!running)
		return;
	
	[locationManager stopUpdatingLocation];
	[self setDataCollected: NO];
	
	running = NO;
}

- (NSMutableDictionary *) readFromPanel {
	NSMutableDictionary *dict = [super readFromPanel];
	
	// store values
	[dict setValue: coordinates forKey: @"parameter"];
	if (![dict objectForKey: @"description"])
		[dict setValue: address forKey: @"description"];
	
	return dict;
}

- (void) writeToPanel: (NSDictionary *) dict usingType: (NSString *) type {
	[super writeToPanel: dict usingType: type];
	
	// get location data
	double lat = current.coordinate.latitude;
	double lon = current.coordinate.longitude;
	
	// do we already have settings?
	if ([dict objectForKey:@"parameter"])
		[CoreLocationSource stringToCoordinates: [dict objectForKey:@"parameter"] toLatitude: &lat andLongitude: &lon];
	
	// show values
	[self setValue: [NSString stringWithFormat: @"%lf, %lf", lat, lon] forKey: @"coordinates"];
	[self setValue: [CoreLocationSource reverseGeocodeWithLatitude: lat andLongitude: lon] forKey: @"address"];
	[self updateMap];
}

- (NSString *) name {
	return @"CoreLocation";
}

- (BOOL) doesRuleMatch: (NSDictionary *) rule {
	// TODO: implement this
	return NO;
}

- (IBAction) showCoreLocation: (id) sender {
	double lat = current.coordinate.latitude;
	double lon = current.coordinate.longitude;
	
	// show values
	[self setValue: [NSString stringWithFormat: @"%lf, %lf", lat, lon] forKey: @"coordinates"];
	[self setValue: [CoreLocationSource reverseGeocodeWithLatitude: lat andLongitude: lon] forKey: @"address"];
	[self updateMap];
}

- (BOOL) validateAddress: (inout NSString **) newValue error: (out NSError **) outError {
	double lat, lon;
	
	// check address
	BOOL result = [CoreLocationSource geocodeAddress: newValue toLatitude: &lat andLongitude: &lon];
	
	// if correct, set coordinates
	if (result) {
		address = [*newValue copy];
		[self setValue: [NSString stringWithFormat: @"%lf, %lf", lat, lon] forKey: @"coordinates"];
		[self updateMap];
	}
	
	return result;
}

- (BOOL) validateCoordinates: (inout NSString **) newValue error: (out NSError **) outError {
	BOOL valid;
	double lat, lon;
	
	// check coordinates
	valid = [CoreLocationSource stringToCoordinates: *newValue toLatitude: &lat andLongitude: &lon];
	
	// if correct, set address
	if (valid) {
		coordinates = [*newValue copy];
		[self setValue: [CoreLocationSource reverseGeocodeWithLatitude: lat andLongitude: lon] forKey: @"address"];
		[self updateMap];
	}
	
	return valid;
}

#pragma mark -
#pragma mark CoreLocation callbacks

- (void) locationManager: (CLLocationManager *) manager
	 didUpdateToLocation: (CLLocation *) newLocation
			fromLocation: (CLLocation *) oldLocation {
	
	DSLog(@"collected: %@", dataCollected ? @"yes" : @"no");
	
	// Ignore updates where nothing we care about changed
	if (newLocation.coordinate.longitude == oldLocation.coordinate.longitude &&
		newLocation.coordinate.latitude == oldLocation.coordinate.latitude &&
		newLocation.horizontalAccuracy == oldLocation.horizontalAccuracy)
		return;
	
	// location
	current = [newLocation copy];
	CLLocationDegrees lat = current.coordinate.latitude;
	CLLocationDegrees lon = current.coordinate.longitude;
	CLLocationAccuracy acc = current.horizontalAccuracy;
	DSLog(@"New location: (%lf, %lf) with accuracy %lf", lat, lon, acc);
	
	// store
	[self setValue: [NSString stringWithFormat: @"%d m", (int) acc] forKey: @"accuracy"];
	[self setDataCollected: YES];
}

- (void) locationManager: (CLLocationManager *) manager didFailWithError: (NSError *) error {
	DSLog(@"Location manager failed with error: %@", [error localizedDescription]);
	
	switch (error.code) {
		case kCLErrorDenied:
			DSLog(@"Core Location denied!");
			[self stop];
			break;
		default:
			break;
	}
}

#pragma mark -
#pragma mark Helper functions

- (void) updateMap {
	double lat, lon;
	NSString *htmlPath = [[NSBundle mainBundle] pathForResource:@"CoreLocationMap" ofType:@"html"];
	
	// Load the HTML file
	NSString *htmlString = [NSString stringWithContentsOfFile: htmlPath encoding: NSUTF8StringEncoding error: NULL];
	
	// Get coordinates and replace placeholders with these
	[CoreLocationSource stringToCoordinates: coordinates toLatitude: &lat andLongitude: &lon];
	htmlString = [NSString stringWithFormat: htmlString, lat, lon];
	
	// Load the HTML in the WebView
	[[webView mainFrame] loadHTMLString: htmlString baseURL: nil];
}

+ (BOOL) geocodeAddress: (NSString **) address toLatitude: (double*) latitude andLongitude: (double*) longitude {
	NSString *param = [*address stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
	NSString *url = [NSString stringWithFormat: @"%@address=%@&sensor=false", kGoogleAPIPrefix, param];
	DSLog(@"%@", url);
	
	// fetch and parse response
	NSData *jsonData = [NSData dataWithContentsOfURL: [NSURL URLWithString: url]];
	if (!jsonData)
		return NO;
	NSDictionary *data = [[JSONDecoder decoder] objectWithData: jsonData];
	
	// check response status
	if (![[data objectForKey: @"status"] isEqualToString: @"OK"])
		return NO;
	
	// check number of results
	if ([[data objectForKey: @"results"] count] == 0)
		return NO;
	NSDictionary *result = [[data objectForKey: @"results"] objectAtIndex: 0];
	
	*address = [[result objectForKey: @"formatted_address"] copy];
	*latitude = [[[[result objectForKey: @"geometry"] objectForKey: @"location"] objectForKey: @"lat"] doubleValue];
	*longitude = [[[[result objectForKey: @"geometry"] objectForKey: @"location"] objectForKey: @"lng"] doubleValue];
	
	return YES;
}

+ (NSString *) reverseGeocodeWithLatitude: (double) latitude andLongitude: (double) longitude {
	NSString *url = [NSString stringWithFormat: @"%@latlng=%lf,%lf&sensor=false", kGoogleAPIPrefix, latitude, longitude];
	
	// fetch and parse response
	NSData *jsonData = [NSData dataWithContentsOfURL: [NSURL URLWithString: url]];
	if (!jsonData)
		return NSLocalizedString(@"Couldn't fetch location address", @"CoreLocation");
	NSDictionary *data = [[JSONDecoder decoder] objectWithData: jsonData];
	
	// check response status
	if (![[data objectForKey: @"status"] isEqualToString: @"OK"])
		return NSLocalizedString(@"Couldn't fetch location address", @"CoreLocation");
	
	// check number of results
	NSArray *results = [data objectForKey: @"results"];
	if ([results count] == 0)
		return NSLocalizedString(@"Unknown location", @"CoreLocation");
	
	return [[results objectAtIndex: 0] objectForKey: @"formatted_address"];
}

+ (BOOL) stringToCoordinates: (in NSString *) text
				  toLatitude: (out double*) latitude
				andLongitude: (out double*) longitude {
	
	// split
	NSArray *comp = [text componentsSeparatedByString: @","];
	if ([comp count] != 2)
		return NO;
	
	// get values
	*latitude = [[comp objectAtIndex: 0] doubleValue];
	*longitude = [[comp objectAtIndex: 1] doubleValue];
	
	return YES;
}

@end
