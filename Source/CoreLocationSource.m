//
//	CoreLocationSource.m
//	ControlPlane
//
//	Created by David Jennes on 03/09/11.
//	Copyright 2011. All rights reserved.
//

#import "CoreLocationSource.h"
#import "DSLogger.h"

@implementation CoreLocationSource

- (id) init {
    self = [super init];//initWithNibNamed:@"IPRule"];
    if (!self)
        return nil;
    
	locationManager = [[CLLocationManager alloc] init];
	locationManager.delegate = self;
	
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
	DSLog(@"Start CoreLocation");
	
	running = YES;
}

- (void) stop {
	if (!running)
		return;
	
	[locationManager stopUpdatingLocation];
	[self setDataCollected: NO];
	DSLog(@"Stop CoreLocation");
	
	running = NO;
}

- (NSMutableDictionary *) readFromPanel {
	NSMutableDictionary *dict = [super readFromPanel];
	
	//NSString *param = [NSString stringWithFormat:@"%@,%@", ruleIP, ruleNetmask];
	//[dict setValue:param forKey:@"parameter"];
	//	if (![dict objectForKey:@"description"])
	//		[dict setValue:param forKey:@"description"];
	
	return dict;
}

- (void) writeToPanel: (NSDictionary *) dict usingType: (NSString *) type {
	[super writeToPanel:dict usingType: type];
	
/*	NSArray *arr = [NSArray arrayWithArray: addresses];
	
	[ruleComboBox removeAllItems];
	[ruleComboBox addItemsWithObjectValues:arr];
	
	NSString *addr = @"", *nmask = @"255.255.255.255";
	if ([arr count] > 0)
		addr = [arr objectAtIndex:0];
	if ([dict objectForKey:@"parameter"]) {
		NSArray *comp = [[dict valueForKey:@"parameter"] componentsSeparatedByString:@","];
		if ([comp count] == 2) {
			addr = [comp objectAtIndex:0];
			nmask = [comp objectAtIndex:1];
			
			if (![[ruleComboBox objectValues] containsObject:addr])
				[ruleComboBox addItemWithObjectValue:addr];
			[ruleComboBox selectItemWithObjectValue:addr];
		}
	}
	[self setValue:addr forKey:@"ruleIP"];
	[self setValue:nmask forKey:@"ruleNetmask"];*/
}

- (NSString *) name {
	return @"CoreLocation";
}

- (BOOL) doesRuleMatch: (NSDictionary *) rule {
	return NO;
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
	CLLocationDegrees lat = newLocation.coordinate.latitude;
	CLLocationDegrees lon = newLocation.coordinate.longitude;
	CLLocationAccuracy acc = newLocation.horizontalAccuracy;
	
	DSLog(@"New location: (%lf, %lf) with accuracy %lf", lat, lon, acc);
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

#pragma mark Location calculation helpers

+ (double) latitudeRangeForLocation: (CLLocation *) location {
	const double M = 6367000.0;	// approximate average meridional radius of curvature of earth
	const double metersToLatitude = 1.0 / ((M_PI / 180.0) * M);
	const double accuracyToWindowScale = 2.0;
	
	return location.horizontalAccuracy * metersToLatitude * accuracyToWindowScale;
}

+ (double) longitudeRangeForLocation: (CLLocation *) location {
	double latitudeRange = [CoreLocationSource latitudeRangeForLocation: location];
	
	return latitudeRange * cos(location.coordinate.latitude * M_PI / 180.0);
}

@end
