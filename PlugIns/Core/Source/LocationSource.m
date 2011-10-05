//
//  LocationSource.m
//  ControlPlane
//
//  Created by David Jennes on 25/09/11.
//  Copyright 2011. All rights reserved.
//

#import "LocationSource.h"

@implementation LocationSource

registerSourceType(LocationSource)
@synthesize location = m_location;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	self.location = nil;
	m_manager = [[CLLocationManager alloc] init];
	m_manager.delegate = self;
	
	return self;
}

- (void) dealloc {
	[m_manager stopUpdatingLocation];
	[m_manager release];
	
	[super dealloc];
}

#pragma mark - Required implementation of 'CallbackSource' class

- (NSArray *) observableKeys {
	return [NSArray arrayWithObject: @"location"];
}

- (void) registerCallback {
	[m_manager startUpdatingLocation];
}

- (void) unregisterCallback {
	[m_manager stopUpdatingLocation];
}

- (void) checkData {
	CLLocation *oldLocation = self.location;
	CLLocation *newLocation = [m_manager location];
	
	// No new location
	if (!newLocation)
		return;
	
	// Ignore updates where nothing we care about changed
	if (oldLocation &&
		oldLocation.coordinate.longitude == newLocation.coordinate.longitude &&
		oldLocation.coordinate.latitude == newLocation.coordinate.latitude &&
		oldLocation.horizontalAccuracy == newLocation.horizontalAccuracy)
		return;
	
	// Log
	CLLocationDegrees lat = newLocation.coordinate.latitude;
	CLLocationDegrees lon = newLocation.coordinate.longitude;
	CLLocationAccuracy acc = newLocation.horizontalAccuracy;
	DLog(@"New location: (%f, %f) with accuracy %f", lat, lon, acc);
	
	// store it
	self.location = newLocation;
}

#pragma mark - CoreLocation callbacks

- (void) locationManager: (CLLocationManager *) manager
	 didUpdateToLocation: (CLLocation *) newLocation
			fromLocation: (CLLocation *) oldLocation {
	
	[self checkData];
}

- (void) locationManager: (CLLocationManager *) manager didFailWithError: (NSError *) error {
	switch (error.code) {
		case kCLErrorDenied:
			DLog(@"Core Location denied!");
			[self stop];
			break;
		case kCLErrorLocationUnknown:
			DLog(@"Core Location reported an error!");
			break;
		default:
			DLog(@"Core Location failed!");
			break;
	}
}

@end
