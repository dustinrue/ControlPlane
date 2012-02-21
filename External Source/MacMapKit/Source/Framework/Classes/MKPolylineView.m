//
//  MKPolylineView.m
//  MapKit
//
//  Created by Rick Fillion on 7/15/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import "MKPolylineView.h"
#import <CoreLocation/CoreLocation.h>

@implementation MKPolylineView

- (id)initWithPolyline:(MKPolyline *)polyline;
{
    if (self = [super initWithOverlay:polyline])
    {
        self.fillColor = [NSColor clearColor];
    }
    return self;
}

- (void)dealloc
{
    [path release];
    [super dealloc];
}

- (MKPolyline *)polyline
{
    return [super overlay];
}

- (NSString *)viewPrototypeName
{
    return @"google.maps.Polyline";
}

- (NSDictionary *)options
{
    NSMutableDictionary *options = [NSMutableDictionary dictionaryWithDictionary:[super options]];
    
    if (path)
        [options setObject:path forKey:@"path"];
    
    return [[options copy] autorelease];
}

- (void)draw:(WebScriptObject *)overlayScriptObject
{
    if (!path)
    {
        CLLocationCoordinate2D *coordinates = malloc(sizeof(CLLocationCoordinate2D) * [self polyline].coordinateCount);
        NSRange range = NSMakeRange(0, [self polyline].coordinateCount);
        [[self polyline] getCoordinates:coordinates range:range];
        NSMutableArray *newPath = [NSMutableArray array];

        for (int i = 0; i< [self polyline].coordinateCount; i++)
        {
            CLLocationCoordinate2D coordinate = coordinates[i];
            NSString *script = [NSString stringWithFormat:@"new google.maps.LatLng(%f, %f);", coordinate.latitude, coordinate.longitude];
            WebScriptObject *latlng = (WebScriptObject *)[overlayScriptObject evaluateWebScript:script];
            [newPath addObject:latlng];
        }
        path = [[[newPath copy] autorelease] retain];
    }
    
    [super draw:overlayScriptObject];
}

@end
