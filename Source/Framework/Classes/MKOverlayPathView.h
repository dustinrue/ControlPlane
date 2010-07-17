//
//  MKOverlayPathView.h
//  MapKit
//
//  Created by Rick Fillion on 7/12/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MapKit/MKOverlayView.h>

@interface MKOverlayPathView : MKOverlayView {
    NSColor *fillColor;
    NSColor *strokeColor;
    CGFloat lineWidth;
}

@property (nonatomic, retain) NSColor *fillColor;
@property (nonatomic, retain) NSColor *strokeColor;
@property (nonatomic, assign) CGFloat lineWidth;

@end
