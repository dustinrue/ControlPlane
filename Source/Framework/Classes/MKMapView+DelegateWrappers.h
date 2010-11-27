//
//  MKMapView+DelegateWrappers.h
//  MapKit
//
//  Created by Rick Fillion on 7/22/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MapKit/MKMapView.h>

@interface MKMapView (DelegateWrappers)

// Map Position Changes
- (void)delegateRegionWillChangeAnimated:(BOOL)animated;
- (void)delegateRegionDidChangeAnimated:(BOOL)animated;

// Loading the Map Data
- (void)delegateWillStartLoadingMap;
- (void)delegateDidFinishLoadingMap;
- (void)delegateDidFailLoadingMapWithError:(NSError *)error;

// Tracking the User Location
- (void)delegateDidUpdateUserLocation;
- (void)delegateDidFailToLocateUserWithError:(NSError *)error;
- (void)delegateWillStartLocatingUser;
- (void)delegateDidStopLocatingUser;

// Managing Annotation Views
- (void)delegateDidAddAnnotationViews:(NSArray *)annotationViews;

// Dragging an Annotation View
- (void)delegateAnnotationView:(MKAnnotationView *)annotationView didChangeDragState:(MKAnnotationViewDragState)newState fromOldState:(MKAnnotationViewDragState)oldState;

// Selecting Annotation Views
- (void)delegateDidSelectAnnotationView:(MKAnnotationView *)view;
- (void)delegateDidDeselectAnnotationView:(MKAnnotationView *)view;

// Managing Overlay Views
- (void)delegateDidAddOverlayViews:(NSArray *)overlayViews;


@end
