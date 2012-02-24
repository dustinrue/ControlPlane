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

+ (BOOL) convertText: (in NSString *) text toLocation: (out CLLocation **) location;
+ (NSString *) convertLocationToText: (in CLLocation *) location;

@end

@implementation CoreLocationSource


- (id) init {
    self = [super initWithNibNamed:@"CoreLocationRule"];
    if (!self)
        return nil;

	selectedRule = nil;
	startDate = [[NSDate date] retain];
    
    mapAnnotations = [[NSMutableArray alloc] init];
    mapOverlays = [[NSMutableArray alloc] init];

	// for custom panel
	scriptObject = nil;
	address = @"";
	coordinates = @"0.0, 0.0";
	accuracy = @"0 m";
	htmlTemplate = @"";
	
    return self;
}

- (void) dealloc {
	
    [mapView release];
	[selectedRule release];
	
	[super dealloc];
}

- (void) start {
	if (running)
		return;
	
	[self setDataCollected: YES];
    [mapView setShowsUserLocation:YES];
    [mapView setDelegate:self];
	
	running = YES;
}

- (void) stop {
	if (!running)
		return;
	
	[self setDataCollected: NO];
    [mapView setShowsUserLocation:NO];
	
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

    NSString *addressForPanel  = @"";
    NSString *coordsForPanel   = @"0.0, 0.0";
    NSNumber *accuracyForPanel = [NSNumber numberWithFloat:0.0];
    
    [self setValue:addressForPanel forKey:@"address"];
    [self setValue:coordsForPanel forKey:@"coordinates"];
    [self setValue:[NSString stringWithFormat:@"%dm", [accuracyForPanel integerValue]] forKey:@"accuracy"];
    
	// do we already have settings?
	if ([dict objectForKey:@"parameter"]) {
		[CoreLocationSource convertText: [dict objectForKey:@"parameter"] toLocation: &selectedRule];
        
        [mapView setCenterCoordinate:selectedRule.coordinate];
        MKCoordinateRegion theRegion;
        theRegion.center = [mapView centerCoordinate];
        MKCoordinateSpan theSpan = {kLatSpan,kLonSpan};
        theRegion.span = theSpan;
        
        [mapView setRegion:theRegion animated:NO];
        
        MKPointAnnotation *pin = [[[MKPointAnnotation alloc] init] autorelease];
        pin.coordinate = [mapView centerCoordinate];
        pin.title = @"";
        [mapView addAnnotation:pin];
        reverseGeocoder = [[MKReverseGeocoder alloc] initWithCoordinate:selectedRule.coordinate];
        [reverseGeocoder setDelegate:self];
        [reverseGeocoder start];
        
        coordsForPanel = [NSString stringWithFormat:@"%f,%f",selectedRule.coordinate.latitude, selectedRule.coordinate.longitude];
    }
	else {
        MKCoordinateRegion theRegion;
        theRegion.center = [mapView userLocation].coordinate;
        
        MKCoordinateSpan theSpan = {kLatSpan,kLonSpan};
        theRegion.span = theSpan;
        
        
        [mapView setRegion:theRegion animated:NO];
        

		coordsForPanel = [NSString stringWithFormat:@"%f,%f", [mapView centerCoordinate].latitude, [mapView centerCoordinate].longitude];
        

        reverseGeocoder = [[MKReverseGeocoder alloc] initWithCoordinate:[mapView centerCoordinate]];
        [reverseGeocoder setDelegate:self];
        [reverseGeocoder start];
        accuracyForPanel = [NSNumber numberWithFloat:[mapView userLocation].location.horizontalAccuracy];
        [self setValue:[NSString stringWithFormat:@"%dm", [accuracyForPanel integerValue]] forKey:@"accuracy"];
        
    }
	
    [self setValue:coordsForPanel forKey:@"coordinates"];

}

- (NSString *) name {
	return @"CoreLocation";
}

- (BOOL) doesRuleMatch: (NSDictionary *) rule {
	// get coordinates of rule
	CLLocation *ruleLocation = nil;
    
	[CoreLocationSource convertText: [rule objectForKey:@"parameter"] toLocation: &ruleLocation];

    CLLocation *currentLocation = [[[CLLocation alloc] initWithLatitude:[mapView centerCoordinate].latitude longitude:[mapView centerCoordinate].longitude] autorelease];
	// match if distance is smaller than accuracy
	if (ruleLocation && currentLocation)
		return [ruleLocation distanceFromLocation: currentLocation] <= currentLocation.horizontalAccuracy;
	else
		return 0;
}

- (IBAction) showCoreLocation: (id) sender {
    
    NSString *coordsForPanel = @"0.0, 0.0";
	MKCoordinateRegion theRegion;
    theRegion.center = [mapView userLocation].coordinate;
    
    MKCoordinateSpan theSpan = {kLatSpan,kLonSpan};
    theRegion.span = theSpan;
    
    
    [mapView setRegion:theRegion animated:NO];
    
    
    coordsForPanel = [NSString stringWithFormat:@"%f,%f", [mapView centerCoordinate].latitude, [mapView centerCoordinate].longitude];
    
    
    reverseGeocoder = [[MKReverseGeocoder alloc] initWithCoordinate:[mapView centerCoordinate]];
    [reverseGeocoder setDelegate:self];
    [reverseGeocoder start];
    [self setValue:coordsForPanel forKey:@"coordinates"];
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
    DSLog(@"lat/long of the rule is %f/%f", lat,lon);
	*location = [[CLLocation alloc] initWithLatitude: lat longitude: lon];
	
	return YES;
}

+ (NSString *) convertLocationToText: (in CLLocation *) location {
	return [NSString stringWithFormat: @"%f,%f", location.coordinate.latitude, location.coordinate.longitude];
}

#pragma mark -
#pragma mark MKMapKit delegates
- (void)reverseGeocoder:(MKReverseGeocoder *)geocoder didFindPlacemark:(MKPlacemark *)placemark {
    [self setValue:[NSString stringWithFormat:@"%@, %@, %@, %@",[placemark thoroughfare], [placemark locality],[placemark administrativeArea], [placemark countryCode]] forKey:@"address"];
    
}

- (void)reverseGeocoder:(MKReverseGeocoder *)geocoder didFailWithError:(NSError *)error {
    DSLog(@"there was an error %@", error);
    
}

- (void)geocoder:(MKGeocoder *)geocoder didFindCoordinate:(CLLocationCoordinate2D)coordinate {
    
}

- (void)geocoder:(MKGeocoder *)geocoder didFailWithError:(NSError *)error {

}

- (void)mapViewDidFinishLoadingMap:(MKMapView *)mapView {
    //DSLog(@"got map finished loading");
}

- (void)mapViewDidFailLoadingMap:(MKMapView *)mapView withError:(NSError *)error {
    DSLog(@"got map failed to load");
}

- (MKAnnotationView *)mapView:(MKMapView *)aMapView viewForAnnotation:(id <MKAnnotation>)annotation {

    MKPinAnnotationView *view = [[[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"pinmarker"] autorelease];
    view.draggable = YES;

    return view;
}
@end
