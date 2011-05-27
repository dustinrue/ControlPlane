//
//  MKMapView+WebViewIntegration.h
//  MapKit
//
//  Created by Rick Fillion on 7/22/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MapKit/MKMapView.h>

@interface MKMapView (WebViewIntegration)

- (void)setUserLocationMarkerVisible:(BOOL)visible;
- (void)updateUserLocationMarkerWithLocaton:(CLLocation *)location;
- (void)updateOverlayZIndexes;
- (void)updateAnnotationZIndexes;
- (void)annotationScriptObjectSelected:(WebScriptObject *)annotationScriptObject;
- (void)annotationScriptObjectDragStart:(WebScriptObject *)annotationScriptObject;
- (void)annotationScriptObjectDrag:(WebScriptObject *)annotationScriptObject;
- (void)annotationScriptObjectDragEnd:(WebScriptObject *)annotationScriptObject;
- (void)annotationScriptObjectRightClick:(WebScriptObject *)annotationScriptObject;
- (void)webviewReportingRegionChange;
- (void)webviewReportingLoadFailure;
- (void)webviewReportingClick:(NSString *)jsonEncodedLatLng;
- (CLLocationCoordinate2D)coordinateForAnnotationScriptObject:(WebScriptObject *)annotationScriptObject;

@end
