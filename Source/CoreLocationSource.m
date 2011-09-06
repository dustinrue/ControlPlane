//
//	CoreLocationSource.m
//	ControlPlane
//
//	Created by David Jennes on 03/09/11.
//	Copyright 2011. All rights reserved.
//

#import "CoreLocationSource.h"
#import "DSLogger.h"

@interface CoreLocationSource (Private)

- (void) updateMap;
+ (NSString *) reverseGeocodeWithLatitude: (double) latitude andLongitude: (double) longitude;
+ (BOOL) stringToCoordinates: (in NSString *) text toLatitude: (out double*) latitude andLongitude: (out double*) longitude;

@end

@implementation CoreLocationSource

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
	[self setValue: [NSString stringWithFormat: @"%f, %f", lat, lon] forKey: @"coordinates"];
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
	[self setValue: [NSString stringWithFormat: @"%f, %f", lat, lon] forKey: @"coordinates"];
	[self setValue: [CoreLocationSource reverseGeocodeWithLatitude: lat andLongitude: lon] forKey: @"address"];
	[self updateMap];
}

- (BOOL) validateCoordinates: (inout NSString **) newValue error: (out NSError **) outError {
	BOOL valid;
	double lat, lon;
	
	valid = [CoreLocationSource stringToCoordinates: *newValue toLatitude: &lat andLongitude: &lon];
	
	// error if not valid
	if (!valid) {
		if (outError)
			*outError = [NSError errorWithDomain: NSCocoaErrorDomain code: NSKeyValueValidationError userInfo: nil];
		return NO;
	}
	
	// update data
	coordinates = [*newValue copy];
	[self setValue: [CoreLocationSource reverseGeocodeWithLatitude: lat andLongitude: lon] forKey: @"address"];
	[self updateMap];
	
	return YES;
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

+ (NSString *) reverseGeocodeWithLatitude: (double) latitude andLongitude: (double) longitude {
	NSXMLDocument *xmlDoc = nil;
	NSError *error = nil;
	NSArray *elements = nil;
	
	// Google geocoding API
	NSURL *url = [NSURL URLWithString: [NSString stringWithFormat: @"http://maps.googleapis.com/maps/api/geocode/xml?latlng=%lf,%lf&&sensor=false", latitude, longitude]];
	
	// fetch response
	xmlDoc = [[[NSXMLDocument alloc] initWithContentsOfURL: url options: NSXMLDocumentTidyXML error: &error] autorelease];
	if (!xmlDoc)
		return NSLocalizedString(@"Couldn't fetch location address", @"CoreLocation");
	
	// check response status
	elements = [[xmlDoc rootElement] nodesForXPath: @"//GeocodeResponse/status" error: nil];
	if (![[[elements objectAtIndex: 0] stringValue] isEqualToString: @"OK"])
		return NSLocalizedString(@"Couldn't fetch location address", @"CoreLocation");
	
	// extract addresses
	elements = [[xmlDoc rootElement] nodesForXPath: @"//GeocodeResponse/result/formatted_address" error: nil];
	if ([elements count] == 0)
		return NSLocalizedString(@"Unknown location", @"CoreLocation");
	
	// get first address
	return [[elements objectAtIndex: 0] stringValue];
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
