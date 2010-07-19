//
//  MKCircleView.m
//  MapKit
//
//  Created by Rick Fillion on 7/12/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import "MKCircleView.h"
#import <MapKit/MKCircle.h>

@implementation MKCircleView


- (id)initWithCircle:(MKCircle *)aCircle
{
    if (self = [super initWithOverlay:aCircle])
    {
    }
    return self;
}

- (void)dealloc
{
    [latlngCenter release];
    [super dealloc];
}

- (MKCircle *)circle
{
    return [super overlay];
}


- (NSString *)viewPrototypeName
{
    return @"google.maps.Circle";
}

- (NSDictionary *)options
{
    NSMutableDictionary *options = [NSMutableDictionary dictionaryWithDictionary:[super options]];
    
    [options setObject:[NSNumber numberWithFloat:[self circle].radius] forKey:@"radius"];
    
    if (latlngCenter)
        [options setObject:latlngCenter forKey:@"center"];
    
    return [[options copy] autorelease];
}

- (void)draw:(WebScriptObject *)overlayScriptObject
{
    [latlngCenter release];
    NSString *script = [NSString stringWithFormat:@"new google.maps.LatLng(%f, %f);", self.circle.coordinate.latitude, self.circle.coordinate.longitude];
    latlngCenter = (WebScriptObject *)[overlayScriptObject evaluateWebScript:script];
    [latlngCenter retain];
    [super draw:overlayScriptObject];
}

@end
