//
//	CoreLocationSource.h
//	ControlPlane
//
//	Created by David Jennes on 03/09/11.
//  Copyright 2011. All rights reserved.
//

#import "EvidenceSource.h"
#import <CoreLocation/CoreLocation.h>
#import <WebKit/WebKit.h>

@interface CoreLocationSource : EvidenceSource <CLLocationManagerDelegate> {
	CLLocationManager *locationManager;
	CLLocation *current;
	
	// for custom panel
	IBOutlet WebView *webView;
	NSString *address;
	NSString *coordinates;
	NSString *accuracy;
}

- (id) init;
- (void) dealloc;
- (void) start;
- (void) stop;

- (NSMutableDictionary *) readFromPanel;
- (void) writeToPanel: (NSDictionary *) dict usingType: (NSString *) type;
- (NSString *) name;
- (BOOL) doesRuleMatch: (NSDictionary *) rule;

- (IBAction) showCoreLocation: (id) sender;
- (BOOL) validateCoordinates: (inout NSString **) newValue error: (out NSError **) outError;

@end
