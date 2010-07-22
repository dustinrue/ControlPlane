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

- (void)delegateRegionWillChangeAnimated:(BOOL)animated;
- (void)delegateRegionDidChangeAnimated:(BOOL)animated;
- (void)delegateDidUpdateUserLocation;
- (void)delegateDidFailToLocateUserWithError:(NSError *)error;
- (void)delegateWillStartLocatingUser;
- (void)delegateDidStopLocatingUser;
- (void)delegateDidAddOverlayViews:(NSArray *)overlayViews;
- (void)delegateDidAddAnnotationViews:(NSArray *)annotationViews;
- (void)delegateDidSelectAnnotationView:(MKAnnotationView *)view;
- (void)delegateDidDeselectAnnotationView:(MKAnnotationView *)view;
- (void)delegateAnnotationView:(MKAnnotationView *)annotationView didChangeDragState:(MKAnnotationViewDragState)newState fromOldState:(MKAnnotationViewDragState)oldState;

@end
