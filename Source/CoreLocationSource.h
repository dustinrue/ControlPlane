//
//	CoreLocationSource.h
//	ControlPlane
//
//	Created by David Jennes on 03/09/11.
//  Copyright 2011. All rights reserved.
//

#import "EvidenceSource.h"
#import <CoreLocation/CoreLocation.h>

@interface CoreLocationSource : EvidenceSource <CLLocationManagerDelegate> {
	CLLocationManager *locationManager;
}

- (id) init;
- (void) dealloc;
- (void) start;
- (void) stop;

- (NSMutableDictionary *) readFromPanel;
- (void) writeToPanel: (NSDictionary *) dict usingType: (NSString *) type;
- (NSString *) name;
- (BOOL) doesRuleMatch: (NSDictionary *) rule;

@end
