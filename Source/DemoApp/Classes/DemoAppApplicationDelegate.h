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

@interface DemoAppApplicationDelegate : NSObject <NSApplicationDelegate, MKMapViewDelegate> {
    NSWindow *window;
    IBOutlet MKMapView *mapView;
    NSNumber *circleRadius;
}

@property (assign) IBOutlet NSWindow *window;


- (IBAction)setMapType:(id)sender;
- (IBAction)addCircle:(id)sender;
- (IBAction)addPin:(id)sender;

@end
