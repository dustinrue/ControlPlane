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

@interface CoreLocationSource () {
	CLLocationManager *locationManager;
	CLLocation *current, *selectedRule;
	NSDate *startDate;
	
	// for custom panel
	IBOutlet WebView *webView;
	NSString *address;
	NSString *coordinates;
	NSString *accuracy;
}

- (void) updateMap;
+ (BOOL) geocodeAddress: (inout NSString **) address toLocation: (out CLLocation **) location;
+ (BOOL) geocodeLocation: (in CLLocation *) location toAddress: (out NSString **) address;
- (BOOL) isValidLocation: (CLLocation *) newLocation withOldLocation:(CLLocation *) oldLocation;
+ (BOOL) convertText: (in NSString *) text toLocation: (out CLLocation **) location;
+ (NSString *) convertLocationToText: (in CLLocation *) location;

@end


@implementation CoreLocationSource

static const NSString *kGoogleAPIPrefix = @"https://maps.googleapis.com/maps/api/geocode/json?";

- (id) init {
    self = [super initWithNibNamed:@"CoreLocationRule"];
    if (!self)
        return nil;
    
	current = nil;
	selectedRule = nil;
	startDate = [[NSDate date] retain];
	
	// for custom panel
	address = @"";
	coordinates = @"0.0, 0.0";
	accuracy = @"0 m";
	
    return self;
}


- (NSString *) description {
    return NSLocalizedString(@"Create rules based on your current location using OS X's Core Location framework.", @"");
}

- (void) dealloc {
	[self stop];
	[locationManager release];
	
	[current release];
	[selectedRule release];
    [startDate release];
	
	[super dealloc];
}

- (void)start {
	if (running) {
		return;
    }
    
    [webView setMaintainsBackForwardList:NO];
    webView.frameLoadDelegate = self;
    
	locationManager = [CLLocationManager new];
	locationManager.delegate = self;
	locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
	[locationManager startUpdatingLocation];
    
	[self setDataCollected: YES];
	[self performSelectorOnMainThread:@selector(updateMap) withObject:nil waitUntilDone:NO];
    
	running = YES;
}

- (void)stop {
	if (!running) {
		return;
    }
    
    if (locationManager) {
        [locationManager stopUpdatingLocation];
        locationManager.delegate = nil;
        [locationManager release];
        locationManager = nil;
    }
    
    //[webView close];
    webView.frameLoadDelegate = nil;
	[webView.mainFrame loadHTMLString:@"" baseURL:NULL];
    
	[self setDataCollected: NO];
	current = nil;
    
	running = NO;
}

- (NSMutableDictionary *) readFromPanel {
	NSMutableDictionary *dict = [super readFromPanel];
	
	// store values
	dict[@"parameter"] = coordinates;
	if (!dict[@"description"]) {
		dict[@"description"] = address;
    }
	
	return dict;
}

- (void) writeToPanel: (NSDictionary *) dict usingType: (NSString *) type {
	[super writeToPanel: dict usingType: type];
	NSString *add = @"";
	
	// do we already have settings?
	if (dict[@"parameter"])
		[CoreLocationSource convertText:dict[@"parameter"] toLocation:&selectedRule];
	else
		selectedRule = [current copy];
	
	// get corresponding address
	if (![CoreLocationSource geocodeLocation: selectedRule toAddress: &add])
		add = NSLocalizedString(@"Unknown address", @"CoreLocation");
	
	// show values
	[self setValue: [CoreLocationSource convertLocationToText: selectedRule] forKey: @"coordinates"];
	[self setValue: add forKey: @"address"];
	[self performSelectorOnMainThread: @selector(updateMap) withObject: nil waitUntilDone: NO];
}

- (NSString *) name {
	return @"CoreLocation";
}

- (BOOL) doesRuleMatch: (NSDictionary *) rule {
	BOOL match = NO;
    
    if (current) {
        // get coordinates of rule
        CLLocation *ruleLocation = nil;
        
        if ([CoreLocationSource convertText:rule[@"parameter"] toLocation:&ruleLocation] && ruleLocation) {
            // match if distance is smaller than accuracy
            match = ([ruleLocation distanceFromLocation: current] <= current.horizontalAccuracy);
            [ruleLocation release];
        }
    }

    return match;
}

- (IBAction) showCoreLocation: (id) sender {
	NSString *add = nil;
	
	selectedRule = [current copy];
	if (![CoreLocationSource geocodeLocation: selectedRule toAddress: &add])
		add = NSLocalizedString(@"Unknown address", @"CoreLocation");
	
	// show values
	[self setValue: [CoreLocationSource convertLocationToText: selectedRule] forKey: @"coordinates"];
	[self setValue: add forKey: @"address"];
	[self performSelectorOnMainThread: @selector(updateMap) withObject: nil waitUntilDone: NO];
}

#pragma mark -
#pragma mark UI Validation

- (BOOL) validateAddress: (inout NSString **) newValue error: (out NSError **) outError {
	CLLocation *loc = nil;
	
	// check address
	BOOL result = [CoreLocationSource geocodeAddress: newValue toLocation: &loc];
	
	// if correct, set coordinates
	if (result) {
		selectedRule = loc;
		
		[self setValue: [CoreLocationSource convertLocationToText: loc] forKey: @"coordinates"];
		[self setValue: *newValue forKey: @"address"];
		[self performSelectorOnMainThread: @selector(updateMap) withObject: nil waitUntilDone: NO];
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
		selectedRule = loc;
		[CoreLocationSource geocodeLocation: loc toAddress: &add];
		
		[self setValue: *newValue forKey: @"coordinates"];
		[self setValue: add forKey: @"address"];
		[self performSelectorOnMainThread: @selector(updateMap) withObject: nil waitUntilDone: NO];
	}
	
	return result;
}

#pragma mark -
#pragma mark JavaScript stuff

- (void) updateSelectedWithLatitude: (NSNumber *) latitude andLongitude: (NSNumber *) longitude {
	NSString *add = nil;
	
	selectedRule = [[CLLocation alloc] initWithLatitude: [latitude doubleValue] longitude: [longitude doubleValue]];
	if (![CoreLocationSource geocodeLocation: selectedRule toAddress: &add])
		add = NSLocalizedString(@"Unknown address", @"CoreLocation");
	
	// show values
	[self setValue: [CoreLocationSource convertLocationToText: selectedRule] forKey: @"coordinates"];
	[self setValue: add forKey: @"address"];
}

- (void) webView: (WebView *) sender didFinishLoadForFrame: (WebFrame *) frame {
	if (frame == [frame findFrameNamed:@"_top"]) {
		[[sender windowScriptObject] setValue: self forKey:@"cocoa"];
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
	
	// Ignore invalid updates
	if (![self isValidLocation: newLocation withOldLocation: oldLocation])
		return;
	
	// location
	current = [newLocation copy];
	CLLocationAccuracy acc = current.horizontalAccuracy;
#ifdef DEBUG_MODE
	CLLocationDegrees lat = current.coordinate.latitude;
	CLLocationDegrees lon = current.coordinate.longitude;
	DSLog(@"New location: (%f, %f) with accuracy %f", lat, lon, acc);
#endif
	
	// store
	[self setValue: [NSString stringWithFormat: @"%d m", (int) acc] forKey: @"accuracy"];
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
	// Get coordinates and replace placeholders with these
    NSString *htmlPath = [NSBundle.mainBundle pathForResource:@"CoreLocationMap" ofType:@"html"];
	NSString *htmlTemplate = [NSString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:NULL];
    
#ifdef DEBUG_MODE
    NSLog(@"htmlTemplate %@", htmlTemplate);
#endif
	NSString *htmlString = [NSString stringWithFormat: htmlTemplate,
							(current ? current.coordinate.latitude : 0.0),
							(current ? current.coordinate.longitude : 0.0),
							(selectedRule ? selectedRule.coordinate.latitude : 0.0),
							(selectedRule ? selectedRule.coordinate.longitude : 0.0),
							(current ? current.horizontalAccuracy : 0.0)];
#ifdef DEBUG_MODE
	NSLog(@"htmlString is %@", htmlString);
#endif
	// Load the HTML in the WebView
	[webView.mainFrame loadHTMLString: htmlString baseURL: nil];
}

+ (BOOL) geocodeAddress: (NSString **) address toLocation: (CLLocation **) location {
	NSString *param = [*address stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
	NSString *url = [NSString stringWithFormat: @"%@address=%@&sensor=false", kGoogleAPIPrefix, param];
#ifdef DEBUG_MODE
	DSLog(@"%@", url);
#endif
	
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

- (BOOL) isValidLocation: (CLLocation *) newLocation withOldLocation:(CLLocation *) oldLocation {
	// Filter out nil locations
	if (!newLocation)
		return NO;
	
	// Filter out points by invalid accuracy
	if (newLocation.horizontalAccuracy < 0)
		return NO;
	
	// Filter out points that are out of order
	NSTimeInterval secondsSinceLastPoint = [newLocation.timestamp timeIntervalSinceDate: oldLocation.timestamp];
	if (secondsSinceLastPoint < 0)
		return NO;

	// Filter out points created before the manager was initialized
	NSTimeInterval secondsSinceManagerStarted = [newLocation.timestamp timeIntervalSinceDate: startDate];
	if (secondsSinceManagerStarted < 0)
		return NO;
	
	// The newLocation is good to use
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
#ifdef DEBUG_MODE
    DSLog(@"lat/long of the rule is %f/%f", lat,lon);
#endif
	*location = [[CLLocation alloc] initWithLatitude: lat longitude: lon];
	
	return YES;
}

- (void)wakeFromSleep:(id)arg {
    if (running)
        [locationManager startUpdatingLocation];
}

- (void) goingToSleep:(id)arg {
    if (running)
        [locationManager stopUpdatingLocation];
}

+ (NSString *) convertLocationToText: (in CLLocation *) location {
	return [NSString stringWithFormat: @"%f,%f", location.coordinate.latitude, location.coordinate.longitude];
}

- (NSString *) friendlyName {
    return NSLocalizedString(@"Current Location", @"");
}

@end
