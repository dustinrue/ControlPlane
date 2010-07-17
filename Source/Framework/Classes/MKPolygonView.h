//
//  MKPolygonView.h
//  MapPrototype
//
//  Created by Rick Fillion on 7/15/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MKPolygon.h"
#import "MKOverlayPathView.h"

@interface MKPolygonView : MKOverlayPathView{
    NSArray *path;
    NSArray *interiorPaths;
}

- (id)initWithPolygon:(MKPolygon *)polygon;

@property (nonatomic, readonly) MKPolygon *polygon;

@end

