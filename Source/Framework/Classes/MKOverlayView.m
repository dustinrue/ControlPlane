//
//  MKOverlayView.m
//  MapKit
//
//  Created by Rick Fillion on 7/12/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import "MKOverlayView.h"

@implementation MKOverlayView

@synthesize overlay;

- (id)initWithOverlay:(id <MKOverlay>)anOverlay
{
    if (self = [super init])
    {
        overlay = [anOverlay retain];
    }
    return self;
}


- (NSString *)objectName
{
    return @"MVCObject";
}

- (NSDictionary *)options
{
    return [NSDictionary dictionary];
}

- (void)dealloc
{
    [overlay release];
    [super dealloc];
}

- (void)draw:(WebScriptObject *)overlayScriptObject
{
    WebScriptObject *windowScriptObject = (WebScriptObject *)[overlayScriptObject evaluateWebScript:@"window"];
    NSDictionary *theOptions = [self options];
    
    for (NSString *key in [theOptions allKeys])
    {
        id value = [theOptions objectForKey:key];
        [windowScriptObject callWebScriptMethod:@"setOverlayOption" withArguments:[NSArray arrayWithObjects:overlayScriptObject, key, value, nil]];
        //NSLog(@"return value from setOption = %@", val);
    }
}

- (WebScriptObject *)overlayScriptObjectFromMapSriptObject:(WebScriptObject *)mapScriptObject
{
    NSString *script = [NSString stringWithFormat:@"new %@()", [self objectName]];
    WebScriptObject *object = (WebScriptObject *)[mapScriptObject evaluateWebScript:script];
    NSArray *args = [NSArray arrayWithObject: [self options]];
    [object callWebScriptMethod:@"setOptions" withArguments:args];
    return object;
}


@end
