//
//  LocationRule.m
//  ControlPlane
//
//  Created by David Jennes on 25/09/11.
//  Copyright 2011. All rights reserved.
//

#import "CLLocation+Geocoding.h"
#import "LocationRule.h"
#import "LocationSource.h"

@implementation LocationRule

registerRuleType(LocationRule)

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_location = [[[CLLocation alloc] initWithLatitude: 0.0 longitude: 0.0] autorelease];
	
	return self;
}

#pragma mark - Source observe functions

- (void) locationChangedWithOld: (CLLocation *) oldLocation andNew: (CLLocation *) newLocation {
	if (newLocation)
		self.match = [m_location distanceFromLocation: newLocation] <= newLocation.horizontalAccuracy;
	else
		self.match = NO;
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"Location", @"Rule type");
}

- (NSString *) category {
	return NSLocalizedString(@"Network", @"Rule category");
}

- (void) beingEnabled {
	Source *source = [SourcesManager.sharedSourcesManager registerRule: self toSource: @"LocationSource"];
	
	// currently a match?
	[self locationChangedWithOld: nil andNew: ((LocationSource *) source).location];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unRegisterRule: self fromSource: @"LocationSource"];
}

- (void) loadData: (id) data {
	CLLocationDegrees lat = [[data objectForKey: @"latitude"] doubleValue];
	CLLocationDegrees lng = [[data objectForKey: @"longitude"] doubleValue];
	
	m_location = [[[CLLocation alloc] initWithLatitude: lat longitude: lng] autorelease];
}

- (NSString *) describeValue: (id) value {
	CLLocationDegrees lat = [[value objectForKey: @"latitude"] doubleValue];
	CLLocationDegrees lng = [[value objectForKey: @"longitude"] doubleValue];
	CLLocation *location = [[[CLLocation alloc] initWithLatitude: lat longitude: lng] autorelease];
	
	NSString *description = [location reverseGeocode];
	if (!description)
		description = NSLocalizedString(@"Unknown location", @"LocationRule value description");
	
	return description;
}

- (NSArray *) suggestedValues {
	LocationSource *source = (LocationSource *) [SourcesManager.sharedSourcesManager getSource: @"LocationSource"];
	
	CLLocation *location = source.location;
	if (!location)
		location = [[[CLLocation alloc] initWithLatitude: 0.0 longitude: 0.0] autorelease];
	
	// location to dictionary
	return [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithDouble: location.coordinate.latitude], @"latitude",
			[NSNumber numberWithDouble: location.coordinate.longitude], @"longitude",
			nil];
}

@end
