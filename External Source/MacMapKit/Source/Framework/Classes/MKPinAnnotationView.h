//
//  MKPinAnnotationView.h
//  MapKit
//
//  Created by Rick Fillion on 7/18/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MapKit/MKAnnotationView.h>

enum {
    MKPinAnnotationColorRed = 0,
    MKPinAnnotationColorGreen,
    MKPinAnnotationColorPurple
};
typedef NSUInteger MKPinAnnotationColor;


@interface MKPinAnnotationView : MKAnnotationView
{
    MKPinAnnotationColor pinColor;
    BOOL animatesDrop;
}

@property (nonatomic) MKPinAnnotationColor pinColor;
@property (nonatomic) BOOL animatesDrop;

@end

