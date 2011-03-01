//
//  DemoAppApplicationDelegate.h
//  MapKit
//
//  Created by Rick Fillion on 7/16/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MapKit/MapKit.h>

@class MKMapView;

@interface DemoAppApplicationDelegate : NSObject <NSApplicationDelegate, MKMapViewDelegate, MKReverseGeocoderDelegate, MKGeocoderDelegate> {
    NSWindow *window;
    IBOutlet MKMapView *mapView;
    IBOutlet NSTextField *addressTextField;
    NSNumber *circleRadius;
    NSString *pinTitle;
    NSArray *pinNames;
}

@property (assign) IBOutlet NSWindow *window;
@property (retain) NSString *pinTitle;

- (IBAction)setMapType:(id)sender;
- (IBAction)addCircle:(id)sender;
- (IBAction)addPin:(id)sender;
- (IBAction)searchAddress:(id)sender;
- (IBAction)demo:(id)sender;
- (IBAction)addAdditionalCSS:(id)sender;

@end
