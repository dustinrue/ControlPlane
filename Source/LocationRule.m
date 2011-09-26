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

#pragma mark - Source observe functions

- (void) locationChangedWithOld: (CLLocation *) oldLocation andNew: (CLLocation *) newLocation {
	CLLocationDegrees lat = [[[self.data objectForKey: @"parameter"] objectForKey: @"latitude"] doubleValue];
	CLLocationDegrees lng = [[[self.data objectForKey: @"parameter"] objectForKey: @"longitude"] doubleValue];
	CLLocation *loc = [[[CLLocation alloc] initWithLatitude: lat longitude: lng] autorelease];
	
	if (newLocation)
		self.match = [loc distanceFromLocation: newLocation] <= newLocation.horizontalAccuracy;
	else
		self.match = NO;
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"Location", @"Rule type");
}

- (void) beingEnabled {
	Source *source = [SourcesManager.sharedSourcesManager registerRule: self toSource: @"LocationSource"];
	
	// currently a match?
	[self locationChangedWithOld: nil andNew: ((LocationSource *) source).location];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unRegisterRule: self fromSource: @"LocationSource"];
}

- (NSArray *) suggestedValues {
	LocationSource *source = (LocationSource *) [SourcesManager.sharedSourcesManager getSource: @"LocationSource"];
	CLLocation *location = source.location;
	NSString *description = nil;
	
	// defaults
	if (location)
		description = [location reverseGeocode];
	else
		location = [[[CLLocation alloc] initWithLatitude: 0.0 longitude: 0.0] autorelease];
	if (!description)
		description = NSLocalizedString(@"Unknown location", @"LocationRule suggestion description");
	
	// location to dictionary
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
						  [NSNumber numberWithDouble: location.coordinate.latitude], @"latitude",
						  [NSNumber numberWithDouble: location.coordinate.longitude], @"longitude",
						  nil];
	
	return [NSArray arrayWithObject:
			[NSDictionary dictionaryWithObjectsAndKeys:
			 dict, @"parameter",
			 description, @"description",
			 nil]];
	return nil;
}

@end
