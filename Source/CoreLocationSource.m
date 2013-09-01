//
//	CoreLocationSource.m
//	ControlPlane
//
//	Created by David Jennes on 03/09/11.
//	Copyright 2011. All rights reserved.
//
//  Code rework and improvements by Vladimir Beloborodov (VladimirTechMan) on 1 September 2013.
//
//  IMPORTANT: This code is intended to be compiled for the ARC mode
//

#import "CoreLocationSource.h"
#import "DSLogger.h"


@implementation CLLocation (CustomExtensions)

- (id)initWithText:(NSString *)text {
    NSArray *comp = [text componentsSeparatedByString:@","];
	if ([comp count] != 2) {
		return nil;
    }
	return [self initWithLatitude:[comp[0] doubleValue] longitude:[comp[1] doubleValue]];
}

- (NSString *)convertToText {
	return [NSString stringWithFormat:@"%f, %f", self.coordinate.latitude, self.coordinate.longitude];
}

@end


@implementation CoreLocationSource {
	CLLocationManager *locationManager;
	CLLocation *current, *selectedRule;
	NSDate *startDate;
	
	// for custom panel
	IBOutlet WebView *webView;
	NSString *address;
	NSString *coordinates;
	NSString *accuracy;
}

static const NSString *kGoogleAPIPrefix = @"https://maps.googleapis.com/maps/api/geocode/json?";

- (id)init {
    self = [super initWithNibNamed:@"CoreLocationRule"];
    if (!self) {
        return nil;
    }
    
	// for custom panel
	address = @"";
	coordinates = @"0.0, 0.0";
	accuracy = @"0 m";
	
    return self;
}

- (NSString *)description {
    return NSLocalizedString(@"Create rules based on your current location using OS X's Core Location framework.", @"");
}

- (void)dealloc {
	[self stop];
}

- (void)start {
	if (running) {
		return;
    }
    
	startDate = [NSDate date];
    
    [webView setMaintainsBackForwardList:NO];
    webView.frameLoadDelegate = self;
    
	locationManager = [[CLLocationManager alloc] init];
	locationManager.delegate = self;
	locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
	[locationManager startUpdatingLocation];
    
	[self setDataCollected:YES];
	running = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateMap];
    });
}

- (void)stop {
	if (!running) {
		return;
    }
    
    if (locationManager) {
        [locationManager stopUpdatingLocation];
        locationManager.delegate = nil;
        locationManager = nil;
    }
	current = nil;
    
	[self setDataCollected:NO];
	running = NO;
    
    webView.frameLoadDelegate = nil;
    [webView.windowScriptObject setValue:nil forKey:@"cocoa"];
	[webView.mainFrame loadHTMLString:@"" baseURL:nil];
}

- (NSMutableDictionary *)readFromPanel {
	NSMutableDictionary *dict = [super readFromPanel];
	
	// store values
	dict[@"parameter"] = coordinates;
	if (!dict[@"description"]) {
		dict[@"description"] = address;
    }
	
	return dict;
}

- (void)writeToPanel:(NSDictionary *)dict usingType:(NSString *)type {
	[super writeToPanel: dict usingType: type];
	NSString *add = @"";
	
	// do we already have settings?
	if (dict[@"parameter"]) {
		selectedRule = [[CLLocation alloc] initWithText:dict[@"parameter"]];
    }
	else {
		selectedRule = [current copy];
    }
	
	// get corresponding address
	if (![CoreLocationSource geocodeLocation: selectedRule toAddress: &add]) {
		add = NSLocalizedString(@"Unknown address", @"CoreLocation");
    }
	
	// show values
	[self setValue:[selectedRule convertToText] forKey:@"coordinates"];
	[self setValue:add forKey:@"address"];
    [self updateMap];
}

- (NSString *)name {
	return @"CoreLocation";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule {
    if (current) {
        // get coordinates of rule
        CLLocation *ruleLocation = [[CLLocation alloc] initWithText:rule[@"parameter"]];
        if (ruleLocation) {
            // match if distance is smaller than accuracy
            return ([ruleLocation distanceFromLocation:current] <= current.horizontalAccuracy);
        }
    }
    return NO;
}

- (IBAction)showCoreLocation:(id)sender {
	NSString *add = nil;
	
	selectedRule = [current copy];
	if (![CoreLocationSource geocodeLocation:selectedRule toAddress:&add]) {
		add = NSLocalizedString(@"Unknown address", @"CoreLocation");
    }
	
	// show values
	[self setValue:[selectedRule convertToText] forKey:@"coordinates"];
	[self setValue:add forKey:@"address"];
    [self updateMap];
}

#pragma mark -
#pragma mark UI Validation

- (BOOL)validateAddress:(inout NSString **)newValue error:(out NSError **)outError {
	// check address
	CLLocation *loc = nil;
	BOOL result = [CoreLocationSource geocodeAddress:newValue toLocation:&loc];
	
	// if correct, set coordinates
	if (result) {
		selectedRule = loc;
		
		[self setValue:[loc convertToText] forKey:@"coordinates"];
		[self setValue:*newValue forKey:@"address"];
        [self updateMap];
	}
	
	return result;
}

- (BOOL)validateCoordinates:(inout NSString **)newValue error:(out NSError **)outError {
	// check coordinates
	CLLocation *loc = [[CLLocation alloc] initWithText:*newValue];
	if (!loc) {
        return NO;
    }
    selectedRule = loc;
    
    NSString *add = nil;
    [CoreLocationSource geocodeLocation:loc toAddress:&add];
    
    [self setValue:*newValue forKey:@"coordinates"];
    [self setValue:add forKey:@"address"];
    [self updateMap];
    
	return YES;
}

#pragma mark -
#pragma mark JavaScript stuff

- (void)updateSelectedWithLatitude:(NSNumber *)latitude andLongitude:(NSNumber *)longitude {
	selectedRule = [[CLLocation alloc] initWithLatitude:[latitude doubleValue] longitude:[longitude doubleValue]];
    
	NSString *add = nil;
	if (![CoreLocationSource geocodeLocation:selectedRule toAddress:&add]) {
		add = NSLocalizedString(@"Unknown address", @"CoreLocation");
    }
	
	// show values
	[self setValue:[selectedRule convertToText] forKey:@"coordinates"];
	[self setValue:add forKey:@"address"];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
	if (running && (frame == [frame findFrameNamed:@"_top"])) {
		[sender.windowScriptObject setValue:self forKey:@"cocoa"];
	}
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)selector {
	if (selector == @selector(updateSelectedWithLatitude:andLongitude:)) {
		return NO;
	}
	return YES;
}

+ (NSString *)webScriptNameForSelector:(SEL)sel {
	if (sel == @selector(updateSelectedWithLatitude:andLongitude:)) {
		return @"updateSelected";
    }
	return nil;
}

#pragma mark -
#pragma mark CoreLocation callbacks

- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation {
	
	// Ignore invalid updates
	if (![self isValidLocation:newLocation withOldLocation:oldLocation]) {
		return;
    }
	
	// location
	current = [newLocation copy];
	CLLocationAccuracy acc = current.horizontalAccuracy;
#ifdef DEBUG_MODE
	CLLocationDegrees lat = current.coordinate.latitude;
	CLLocationDegrees lon = current.coordinate.longitude;
	DSLog(@"New location: (%f, %f) with accuracy %f", lat, lon, acc);
#endif
	
	// store
	[self setValue:[NSString stringWithFormat:@"%d m", (int) acc] forKey:@"accuracy"];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
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

- (void)updateMap {
    if (!running) {
        return;
    }
    
    dispatch_queue_t mainQueue = dispatch_get_main_queue();
    if (dispatch_get_current_queue() != mainQueue) {
        dispatch_async(mainQueue, ^{
            [self updateMap];
        });
        return;
    }
    
	// Get coordinates and replace placeholders with these
    NSString *htmlPath = [NSBundle.mainBundle pathForResource:@"CoreLocationMap" ofType:@"html"];
	NSString *htmlTemplate = [NSString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:NULL];
    
#ifdef DEBUG_MODE
    NSLog(@"htmlTemplate %@", htmlTemplate);
#endif
	NSString *htmlString = [NSString stringWithFormat:htmlTemplate,
							(current ? current.coordinate.latitude : 0.0),
							(current ? current.coordinate.longitude : 0.0),
							(selectedRule ? selectedRule.coordinate.latitude : 0.0),
							(selectedRule ? selectedRule.coordinate.longitude : 0.0),
							(current ? current.horizontalAccuracy : 0.0)];
#ifdef DEBUG_MODE
	NSLog(@"htmlString is %@", htmlString);
#endif
	// Load the HTML in the WebView
	[webView.mainFrame loadHTMLString:htmlString baseURL:nil];
}


+ (BOOL)geocodeAddress:(NSString **)address toLocation:(CLLocation **)location {
	NSString *param = [*address stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSString *url = [NSString stringWithFormat:@"%@address=%@&sensor=false", kGoogleAPIPrefix, param];
#ifdef DEBUG_MODE
	DSLog(@"%@", url);
#endif
	
	// fetch and parse response
	NSData *jsonData = [NSData dataWithContentsOfURL:[NSURL URLWithString:url]];
	if (!jsonData) {
		return NO;
    }
	
    NSError *error = nil;
    NSDictionary *data = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    if (!data) {
        DSLog(@"Failed to decode JSON object: '%@'", [error localizedFailureReason]);
        return NO;
    }
	
	// check response status
	if (![data[@"status"] isEqualToString:@"OK"]) {
		return NO;
    }
	
	// check number of results
	if ([data[@"results"] count] == 0) {
		return NO;
    }
	NSDictionary *result = data[@"results"][0];
	
	*address = [result[@"formatted_address"] copy];
    
    NSDictionary *resultLocation = result[@"geometry"][@"location"];
	double lat = [resultLocation[@"lat"] doubleValue];
	double lon = [resultLocation[@"lng"] doubleValue];
	*location = [[CLLocation alloc] initWithLatitude:lat longitude:lon];
	
	return YES;
}

+ (BOOL)geocodeLocation:(CLLocation *)location toAddress:(NSString **)address {
	NSString *url = [NSString stringWithFormat:@"%@latlng=%f,%f&sensor=false",
					 kGoogleAPIPrefix, location.coordinate.latitude, location.coordinate.longitude];
	
	// fetch and parse response
	NSData *jsonData = [NSData dataWithContentsOfURL:[NSURL URLWithString:url]];
	if (!jsonData) {
		return NO;
    }
    
    NSError *error = nil;
    NSDictionary *data = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    if (!data) {
        DSLog(@"Failed to decode JSON object: '%@'", [error localizedFailureReason]);
        return NO;
    }
	
	// check response status
	if (![data[@"status"] isEqualToString: @"OK"]) {
		return NO;
    }
	
	// check number of results
	NSArray *results = data[@"results"];
	if ([results count] == 0) {
		return NO;
    }
	
	*address = results[0][@"formatted_address"];
	return YES;
}

- (BOOL)isValidLocation:(CLLocation *)newLocation withOldLocation:(CLLocation *)oldLocation {
	// Filter out nil locations
	if (!newLocation) {
		return NO;
    }
	// Filter out points by invalid accuracy
	if (newLocation.horizontalAccuracy < 0) {
		return NO;
    }
	// Filter out points that are out of order
	NSTimeInterval secondsSinceLastPoint = [newLocation.timestamp timeIntervalSinceDate:oldLocation.timestamp];
	if (secondsSinceLastPoint < 0) {
		return NO;
    }
	// Filter out points created before the manager was initialized
	NSTimeInterval secondsSinceManagerStarted = [newLocation.timestamp timeIntervalSinceDate:startDate];
	if (secondsSinceManagerStarted < 0) {
		return NO;
    }
	// The newLocation is good to use
	return YES;
}

- (void)wakeFromSleep:(id)arg {
    if (goingToSleep) {
        goingToSleep = NO;
        if (startAfterSleep && ![self isRunning]) {
            startAfterSleep = NO;
            running = YES;
            
            DSLog(@"Starting %@ after sleep.", [self class]);
            [locationManager startUpdatingLocation];
        }
    }
}

- (void)goingToSleep:(id)arg {
    if (!goingToSleep) {
        goingToSleep = YES;
        if ([self isRunning]) {
            startAfterSleep = YES;
            running = NO;
            
            DSLog(@"Stopping %@ for sleep.", [self class]);
            [locationManager stopUpdatingLocation];
        }
    }
}

- (NSString *)friendlyName {
    return NSLocalizedString(@"Current Location", @"");
}

@end
