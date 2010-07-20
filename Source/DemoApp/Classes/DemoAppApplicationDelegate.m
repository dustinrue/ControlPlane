//
//  DemoAppApplicationDelegate.m
//  MapKit
//
//  Created by Rick Fillion on 7/16/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import "DemoAppApplicationDelegate.h"
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

@implementation DemoAppApplicationDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    NSLog(@"applicationDidFinishLaunching:");    
    [mapView setShowsUserLocation: YES];
    [mapView setDelegate: self];
}

- (IBAction)setMapType:(id)sender
{
    NSSegmentedControl *segmentedControl = (NSSegmentedControl *)sender;
    [mapView setMapType:[segmentedControl selectedSegment]];
}
- (IBAction)getCenter:(id)sender
{
    CLLocationCoordinate2D coord = [mapView centerCoordinate];
    NSLog(@"coord = {%f, %f}", coord.longitude, coord.latitude);
    MKCoordinateRegion region = [mapView region];
    NSLog(@"region = {%f, %f} {%f, %f}", region.center.latitude, region.center.longitude, region.span.latitudeDelta, region.span.longitudeDelta);
    
}

- (IBAction)setCenter:(id)sender
{
    CLLocationCoordinate2D coord;
    coord.latitude = 49.88746321737416;
    coord.longitude = -97.14002115786904;
    //[mapView setCenterCoordinate:coord animated:NO];
    
    MKCoordinateRegion region;
    region = [mapView region];
    
    region.center.latitude = 49.887461;
    region.center.longitude = -97.140021;
    region.span.latitudeDelta = 0.009098;
    region.span.longitudeDelta = 0.003830;
    
    //region = [mapView region];
    // NSLog(@"before = {%f, %f} {%f, %f}", region.center.latitude, region.center.longitude, region.span.latitudeDelta, region.span.longitudeDelta);
    [mapView setRegion:region animated: YES];
    region = [mapView region];
    //NSLog(@"after = {%f, %f} {%f, %f}", region.center.latitude, region.center.longitude, region.span.latitudeDelta, region.span.longitudeDelta);
    
}

- (IBAction)checkLocationVisible:(id)sender
{
    BOOL visible = [mapView isUserLocationVisible];
    NSLog(@"visible = %d", visible);
}

#pragma mark MapView Delegate

// Responding to Map Position Changes

- (void)mapView:(MKMapView *)aMapView regionWillChangeAnimated:(BOOL)animated
{
    NSLog(@"mapView: %@ regionWillChangeAnimated: %d", aMapView, animated);
}

- (void)mapView:(MKMapView *)aMapView regionDidChangeAnimated:(BOOL)animated
{
    NSLog(@"mapView: %@ regionDidChangeAnimated: %d", aMapView, animated);
}

//Loading the Map Data
- (void)mapViewWillStartLoadingMap:(MKMapView *)aMapView
{
    NSLog(@"mapViewWillStartLoadingMap: %@", aMapView);
}

- (void)mapViewDidFinishLoadingMap:(MKMapView *)aMapView
{
    NSLog(@"mapViewDidFinishLoadingMap: %@", aMapView);
}

- (void)mapViewDidFailLoadingMap:(MKMapView *)aMapView withError:(NSError *)error
{
    NSLog(@"mapViewDidFailLoadingMap: %@ withError: %@", aMapView, error);
}

// Tracking the User Location
- (void)mapViewWillStartLocatingUser:(MKMapView *)aMapView
{
    //NSLog(@"mapViewWillStartLocatingUser: %@", aMapView);
}

- (void)mapViewDidStopLocatingUser:(MKMapView *)aMapView
{
    //NSLog(@"mapViewDidStopLocatingUser: %@", aMapView);
}

- (void)mapView:(MKMapView *)aMapView didUpdateUserLocation:(MKUserLocation *)userLocation
{
    //NSLog(@"mapView: %@ didUpdateUserLocation: %@", aMapView, userLocation); 
}

- (void)mapView:(MKMapView *)aMapView didFailToLocateUserWithError:(NSError *)error
{
    // NSLog(@"mapView: %@ didFailToLocateUserWithError: %@", aMapView, error);
}

// Managing Annotation Views


- (MKAnnotationView *)mapView:(MKMapView *)aMapView viewForAnnotation:(id <MKAnnotation>)annotation
{
    NSLog(@"mapView: %@ viewForAnnotation: %@", aMapView, annotation);
    //MKAnnotationView *view = [[[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"blah"] autorelease];
    MKPinAnnotationView *view = [[[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"blah"] autorelease];
    //NSString *path = [[NSBundle mainBundle] pathForResource:@"MarkerTest" ofType:@"png"];
    //NSURL *url = [NSURL fileURLWithPath:path];
    //view.imageUrl = [url absoluteString];
    return view;
}
 
- (void)mapView:(MKMapView *)aMapView didAddAnnotationViews:(NSArray *)views
{
    NSLog(@"mapView: %@ didAddAnnotationViews: %@", aMapView, views);
}
 /*
 - (void)mapView:(MKMapView *)aMapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
 {
 NSLog(@"mapView: %@ annotationView: %@ calloutAccessoryControlTapped: %@", aMapView, view, control);
 }
 */

// Dragging an Annotation View
/*
 - (void)mapView:(MKMapView *)aMapView annotationView:(MKAnnotationView *)annotationView 
 didChangeDragState:(MKAnnotationViewDragState)newState 
 fromOldState:(MKAnnotationViewDragState)oldState
 {
 NSLog(@"mapView: %@ annotationView: %@ didChangeDragState: %d fromOldState: %d", aMapView, annotationView, newState, oldState);
 }
 */


// Selecting Annotation Views
/*
 - (void)mapView:(MKMapView *)aMapView didSelectAnnotationView:(MKAnnotationView *)view
 {
 NSLog(@"mapView: %@ didSelectAnnotationView: %@", aMapView, view);
 }
 
 - (void)mapView:(MKMapView *)aMapView didDeselectAnnotationView:(MKAnnotationView *)view
 {
 NSLog(@"mapView: %@ didDeselectAnnotationView: %@", aMapView, view);
 }
 */

// Managing Overlay Views

- (MKOverlayView *)mapView:(MKMapView *)aMapView viewForOverlay:(id <MKOverlay>)overlay
{
    //NSLog(@"mapView: %@ viewForOverlay: %@", aMapView, overlay);
    MKCircleView *circleView = [[[MKCircleView alloc] initWithCircle:overlay] autorelease];
    return circleView;
    //    MKPolylineView *polylineView = [[[MKPolylineView alloc] initWithPolyline:overlay] autorelease];
    //    return polylineView;
    MKPolygonView *polygonView = [[[MKPolygonView alloc] initWithPolygon:overlay] autorelease];
    return polygonView;
}

- (void)mapView:(MKMapView *)aMapView didAddOverlayViews:(NSArray *)overlayViews
{
    NSLog(@"mapView: %@ didAddOverlayViews: %@", aMapView, overlayViews);
}


@end
