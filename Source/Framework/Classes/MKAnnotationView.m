//
//  MKAnnotationView.m
//  MapKit
//
//  Created by Rick Fillion on 7/18/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import "MKAnnotationView.h"
#import <MapKit/MKAnnotation.h>

@interface MKAnnotationView (Private)

- (WebScriptObject *)markerImageFromScriptObject:(WebScriptObject *)webScriptObject;

@end


@implementation MKAnnotationView

@synthesize reuseIdentifier;
@synthesize annotation;
@synthesize imageUrl;
@synthesize centerOffset;
@synthesize calloutOffset;
@synthesize enabled;
@synthesize highlighted;
@synthesize selected;
@synthesize canShowCallout;
@synthesize draggable;
@synthesize dragState;

- (id)initWithAnnotation:(id <MKAnnotation>)anAnnotation reuseIdentifier:(NSString *)aReuseIdentifier
{
    if (self = [super init])
    {
        reuseIdentifier = [aReuseIdentifier retain];
        self.annotation = anAnnotation;
    }
    return self;
}

- (void)dealloc
{
    [reuseIdentifier release];
    [(id)annotation release];
    [markerImage release];
    [latlngCenter release];
    [super dealloc];
}

- (void)prepareForReuse
{
    // Unsupported so far.
}

- (void)setSelected:(BOOL)_selected animated:(BOOL)animated
{
    self.selected = _selected;
}

- (NSString *)viewPrototypeName
{
    return @"google.maps.Marker";
}

- (NSDictionary *)options
{
    NSMutableDictionary *options = [NSMutableDictionary dictionaryWithDictionary:[super options]];
    
    if (markerImage)
        [options setObject:markerImage forKey:@"icon"];
    
    if (latlngCenter)
        [options setObject:latlngCenter forKey:@"position"];
    
    if ([self.annotation title])
        [options setObject:[self.annotation title] forKey:@"title"];
    
    [options setObject:[NSNumber numberWithBool:draggable] forKey:@"draggable"];
    //NSLog(@"options = %@", options);
    
    return [[options copy] autorelease];
}

- (void)draw:(WebScriptObject *)overlayScriptObject
{
    if (!markerImage)
    {
        markerImage = [self markerImageFromScriptObject:overlayScriptObject];
        [markerImage retain];
    }
    
    [latlngCenter release];
    NSString *script = [NSString stringWithFormat:@"new google.maps.LatLng(%f, %f);", self.annotation.coordinate.latitude, self.annotation.coordinate.longitude];
    latlngCenter = (WebScriptObject *)[overlayScriptObject evaluateWebScript:script];
    [latlngCenter retain];
    
    [super draw:overlayScriptObject];
}

#pragma mark Private

- (WebScriptObject *)markerImageFromScriptObject:(WebScriptObject *)webScriptObject
{
    if (!self.imageUrl)
        return nil;
    NSString *anchorConstructor = [NSString stringWithFormat:@"new google.maps.Point(%f, %f)", self.centerOffset.x, self.centerOffset.y];
    NSString *markerConstructor = [NSString stringWithFormat:@"new google.maps.MarkerImage('%@', null, null, null, null);", self.imageUrl];
    //NSLog(@"markerConstructor = %@", markerConstructor);
    WebScriptObject *aMmarkerImage = (WebScriptObject *)[webScriptObject evaluateWebScript:markerConstructor];
    return  aMmarkerImage;
}

@end
