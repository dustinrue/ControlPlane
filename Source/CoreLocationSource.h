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
#import <MapKit/MapKit.h>

#define kLatSpan 0.0015
#define kLonSpan 0.0015

@interface CoreLocationSource : EvidenceSource <MKMapViewDelegate,MKGeocoderDelegate,MKReverseGeocoderDelegate> {
	CLLocation *selectedRule;
	NSDate *startDate;
    IBOutlet MKMapView *mapView;
	
	// for custom panel
	IBOutlet WebView *webView;
	WebScriptObject *scriptObject;
	NSString *address;
	NSString *coordinates;
	NSString *accuracy;
	NSString *htmlTemplate;
    
    NSMutableArray *mapAnnotations;
    NSMutableArray *mapOverlays;
    
    MKReverseGeocoder *reverseGeocoder;
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

@end
