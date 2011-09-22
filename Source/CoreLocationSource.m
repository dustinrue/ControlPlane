//
//	CoreLocationSource.m
//	ControlPlane
//
//	Created by David Jennes on 03/09/11.
//	Copyright 2011. All rights reserved.
//

#import "CoreLocationSource.h"
#import "JSONKit.h"

@interface CoreLocationSource (Private)

- (void) updateMap;
+ (BOOL) geocodeAddress: (inout NSString **) address toLocation: (out CLLocation **) location;
+ (BOOL) geocodeLocation: (in CLLocation *) location toAddress: (out NSString **) address;
+ (BOOL) convertText: (in NSString *) text toLocation: (out CLLocation **) location;
+ (NSString *) convertLocationToText: (in CLLocation *) location;

@end

@implementation CoreLocationSource

static const NSString *kGoogleAPIPrefix = @"https://maps.googleapis.com/maps/api/geocode/json?";

- (id) init {
    self = [super initWithNibNamed:@"CoreLocationRule"];
    if (!self)
        return nil;
    
	locationManager = [[CLLocationManager alloc] init];
	locationManager.delegate = self;
	current = nil;
	selected = nil;
	
	// for custom panel
	scriptObject = nil;
	address = @"";
	coordinates = @"0.0, 0.0";
	accuracy = @"0 m";
	
    return self;
}

- (void)awakeFromNib {
	[webView setFrameLoadDelegate: self];
	[[webView mainFrame] loadHTMLString:@"" baseURL:NULL];
}

- (void) dealloc {
	[locationManager stopUpdatingLocation];
	[locationManager release];
	
	[current release];
	[selected release];
	
	[super dealloc];
}

- (void) start {
	if (running)
		return;
	
	[locationManager startUpdatingLocation];
	[self setDataCollected: YES];
	
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
	NSString *add = @"";
	
	// do we already have settings?
	if ([dict objectForKey:@"parameter"])
		[CoreLocationSource convertText: [dict objectForKey:@"parameter"] toLocation: &selected];
	else
		selected = [current copy];
	
	// get corresponding address
	if (![CoreLocationSource geocodeLocation: selected toAddress: &add])
		add = NSLocalizedString(@"Unknown address", @"CoreLocation");
	
	// show values
	[self setValue: [CoreLocationSource convertLocationToText: selected] forKey: @"coordinates"];
	[self setValue: add forKey: @"address"];
	[self updateMap];
}

- (NSString *) name {
	return @"CoreLocation";
}

- (BOOL) doesRuleMatch: (NSDictionary *) rule {
	// get coordinates of rule
	CLLocation *ruleLocation = nil;
	[CoreLocationSource convertText: [rule objectForKey:@"parameter"] toLocation: &ruleLocation];
	
	// match if distance is smaller than accuracy
	if (selected && current)
		return [selected distanceFromLocation: ruleLocation] <= current.horizontalAccuracy;
	else
		return 0;
}

- (IBAction) showCoreLocation: (id) sender {
	NSString *add = nil;
	
	selected = [current copy];
	if (![CoreLocationSource geocodeLocation: selected toAddress: &add])
		add = NSLocalizedString(@"Unknown address", @"CoreLocation");
	
	// show values
	[self setValue: [CoreLocationSource convertLocationToText: selected] forKey: @"coordinates"];
	[self setValue: add forKey: @"address"];
	[self updateMap];
}

#pragma mark -
#pragma mark UI Validation

- (BOOL) validateAddress: (inout NSString **) newValue error: (out NSError **) outError {
	CLLocation *loc = nil;
	
	// check address
	BOOL result = [CoreLocationSource geocodeAddress: newValue toLocation: &loc];
	
	// if correct, set coordinates
	if (result) {
		selected = loc;
		
		[self setValue: [CoreLocationSource convertLocationToText: loc] forKey: @"coordinates"];
		[self setValue: *newValue forKey: @"address"];
		[self updateMap];
	}
	
	return result;
}

- (BOOL) validateCoordinates: (inout NSString **) newValue error: (out NSError **) outError {
	CLLocation *loc = nil;
	NSString *add = nil;
	
	// check coordinates
	BOOL result = [CoreLocationSource convertText: *newValue toLocation: &loc];
	
	// if correct, set address
	if (result) {
		selected = loc;
		[CoreLocationSource geocodeLocation: loc toAddress: &add];
		
		[self setValue: *newValue forKey: @"coordinates"];
		[self setValue: add forKey: @"address"];
		[self updateMap];
	}
	
	return result;
}

#pragma mark -
#pragma mark JavaScript stuff

- (void) updateSelectedWithLatitude: (NSNumber *) latitude andLongitude: (NSNumber *) longitude {
	NSString *add = nil;
	
	selected = [[CLLocation alloc] initWithLatitude: [latitude doubleValue] longitude: [longitude doubleValue]];
	if (![CoreLocationSource geocodeLocation: selected toAddress: &add])
		add = NSLocalizedString(@"Unknown address", @"CoreLocation");
	
	// show values
	[self setValue: [CoreLocationSource convertLocationToText: selected] forKey: @"coordinates"];
	[self setValue: add forKey: @"address"];
}

- (void) webView: (WebView *) sender didFinishLoadForFrame: (WebFrame *) frame {
	if (frame == [frame findFrameNamed:@"_top"]) {
		scriptObject = [sender windowScriptObject];
		[scriptObject setValue: self forKey:@"cocoa"];
	}
}

+ (BOOL) isSelectorExcludedFromWebScript: (SEL) selector {
	if (selector == @selector(updateSelectedWithLatitude:andLongitude:)) {
		return NO;
	}
	
	return YES;
}

+ (NSString *) webScriptNameForSelector: (SEL) sel {
	if (sel == @selector(updateSelectedWithLatitude:andLongitude:))
		return @"updateSelected";
	
	return nil;
}

#pragma mark -
#pragma mark CoreLocation callbacks

- (void) locationManager: (CLLocationManager *) manager
	 didUpdateToLocation: (CLLocation *) newLocation
			fromLocation: (CLLocation *) oldLocation {
	
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
	DLog(@"New location: (%f, %f) with accuracy %f", lat, lon, acc);
	
	// store
	[self setValue: [NSString stringWithFormat: @"%d m", (int) acc] forKey: @"accuracy"];
}

- (void) locationManager: (CLLocationManager *) manager didFailWithError: (NSError *) error {
	DLog(@"Location manager failed with error: %@", [error localizedDescription]);
	
	switch (error.code) {
		case kCLErrorDenied:
			DLog(@"Core Location denied!");
			[self stop];
			break;
		default:
			break;
	}
}

#pragma mark -
#pragma mark Helper functions

- (void) updateMap {
	NSString *htmlPath = [[NSBundle mainBundle] pathForResource:@"CoreLocationMap" ofType:@"html"];
	
	// Load the HTML file
	NSString *htmlString = [NSString stringWithContentsOfFile: htmlPath encoding: NSUTF8StringEncoding error: NULL];
	
	// Get coordinates and replace placeholders with these
	htmlString = [NSString stringWithFormat: htmlString,
				  (current ? current.coordinate.latitude : 0.0),
				  (current ? current.coordinate.longitude : 0.0),
				  (selected ? selected.coordinate.latitude : 0.0),
				  (selected ? selected.coordinate.longitude : 0.0),
				  (current ? current.horizontalAccuracy : 0.0)];
	
	// Load the HTML in the WebView
	[[webView mainFrame] loadHTMLString: htmlString baseURL: nil];
}

+ (BOOL) geocodeAddress: (NSString **) address toLocation: (CLLocation **) location {
	NSString *param = [*address stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
	NSString *url = [NSString stringWithFormat: @"%@address=%@&sensor=false", kGoogleAPIPrefix, param];
	DLog(@"%@", url);
	
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
	double lat = [[[[result objectForKey: @"geometry"] objectForKey: @"location"] objectForKey: @"lat"] doubleValue];
	double lon = [[[[result objectForKey: @"geometry"] objectForKey: @"location"] objectForKey: @"lng"] doubleValue];
	*location = [[CLLocation alloc] initWithLatitude: lat longitude: lon];
	
	return YES;
}

+ (BOOL) geocodeLocation: (CLLocation *) location toAddress: (NSString **) address {
	NSString *url = [NSString stringWithFormat: @"%@latlng=%f,%f&sensor=false",
					 kGoogleAPIPrefix, location.coordinate.latitude, location.coordinate.longitude];
	
	// fetch and parse response
	NSData *jsonData = [NSData dataWithContentsOfURL: [NSURL URLWithString: url]];
	if (!jsonData)
		return NO;
	NSDictionary *data = [[JSONDecoder decoder] objectWithData: jsonData];
	
	// check response status
	if (![[data objectForKey: @"status"] isEqualToString: @"OK"])
		return NO;
	
	// check number of results
	NSArray *results = [data objectForKey: @"results"];
	if ([results count] == 0)
		return NO;
	
	*address = [[results objectAtIndex: 0] objectForKey: @"formatted_address"];
	return YES;
}

+ (BOOL) convertText: (in NSString *) text toLocation: (out CLLocation **) location {
	double lat = 0.0, lon = 0.0;
	
	// split
	NSArray *comp = [text componentsSeparatedByString: @","];
	if ([comp count] != 2)
		return NO;
	
	// get values
	lat = [[comp objectAtIndex: 0] doubleValue];
	lon = [[comp objectAtIndex: 1] doubleValue];
	*location = [[CLLocation alloc] initWithLatitude: lat longitude: lon];
	
	return YES;
}

+ (NSString *) convertLocationToText: (in CLLocation *) location {
	return [NSString stringWithFormat: @"%f,%f", location.coordinate.latitude, location.coordinate.longitude];
}

@end
