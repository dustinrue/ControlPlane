//
//  MKMapView+Additions.m
//  MapKit
//
//  Created by Rick Fillion on 7/24/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import "MKMapView+Additions.h"


@implementation MKMapView (Additions)

- (void)addJavascriptTag:(NSString *)urlString
{
    WebScriptObject *webScriptObject = [webView windowScriptObject];
    NSArray *args = [NSArray arrayWithObject:urlString];
    [webScriptObject callWebScriptMethod:@"addJavascriptTag" withArguments:args];
}

- (void)addStylesheetTag:(NSString *)urlString
{
    WebScriptObject *webScriptObject = [webView windowScriptObject];
    NSArray *args = [NSArray arrayWithObject:urlString];
    [webScriptObject callWebScriptMethod:@"addStylesheetTag" withArguments:args]; 
}

@end
