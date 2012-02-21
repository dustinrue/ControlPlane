//
//  MKPolylineView.h
//  MapKit
//
//  Created by Rick Fillion on 7/15/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MapKit/MKPolyline.h>
#import <MapKit/MKOverlayPathView.h>

@interface MKPolylineView : MKOverlayPathView {
    NSArray *path;
}

- (id)initWithPolyline:(MKPolyline *)polyline;

@property (nonatomic, readonly) MKPolyline *polyline;

@end

