//
//  DemoAppApplicationDelegate.h
//  MapKit
//
//  Created by Rick Fillion on 7/16/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MKMapView;

@interface DemoAppApplicationDelegate : NSObject <NSApplicationDelegate> {
    NSWindow *window;
    IBOutlet MKMapView *mapView;
}

@property (assign) IBOutlet NSWindow *window;


- (IBAction)setMapType:(id)sender;
- (IBAction)getCenter:(id)sender;
- (IBAction)setCenter:(id)sender;
- (IBAction)checkLocationVisible:(id)sender;

@end
