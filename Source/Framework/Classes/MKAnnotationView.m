//
//  MKAnnotationView.m
//  MapKit
//
//  Created by Rick Fillion on 7/18/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import "MKAnnotationView.h"
#import <MapKit/MKAnnotation.h>




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
    return @"AnnotationOverlay";
}

- (NSDictionary *)options
{
    NSMutableDictionary *options = [NSMutableDictionary dictionaryWithDictionary:[super options]];
    
    if (self.imageUrl)
        [options setObject:self.imageUrl forKey:@"imageUrl"];
    
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
 
    [latlngCenter release];
    NSString *script = [NSString stringWithFormat:@"new google.maps.LatLng(%f, %f);", self.annotation.coordinate.latitude, self.annotation.coordinate.longitude];
    latlngCenter = (WebScriptObject *)[overlayScriptObject evaluateWebScript:script];
    [latlngCenter retain];
    
    [super draw:overlayScriptObject];
}

@end
