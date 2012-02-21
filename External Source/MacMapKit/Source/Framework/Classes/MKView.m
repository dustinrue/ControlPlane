//
//  MKView.m
//  MapKit
//
//  Created by Rick Fillion on 7/19/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import "MKView.h"


@implementation MKView

- (NSString *)viewPrototypeName
{
    return @"MVCObject";
}

- (NSDictionary *)options
{
    return [NSDictionary dictionary];
}

- (void)draw:(WebScriptObject *)overlayScriptObject
{
    WebScriptObject *windowScriptObject = (WebScriptObject *)[overlayScriptObject evaluateWebScript:@"window"];
    NSDictionary *theOptions = [self options];
    
    for (NSString *key in [theOptions allKeys])
    {
        id value = [theOptions objectForKey:key];
        [windowScriptObject callWebScriptMethod:@"setOverlayOption" withArguments:[NSArray arrayWithObjects:overlayScriptObject, key, value, nil]];
        //NSLog(@"return value from setOption(%@) = %@",key, val);
    }
}

- (WebScriptObject *)overlayScriptObjectFromMapScriptObject:(WebScriptObject *)mapScriptObject
{
    NSString *script = [NSString stringWithFormat:@"new %@()", [self viewPrototypeName]];
    WebScriptObject *object = (WebScriptObject *)[mapScriptObject evaluateWebScript:script];
    return object;
}



@end
