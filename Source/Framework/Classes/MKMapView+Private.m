//
//  MKMapView+Private.m
//  MapKit
//
//  Created by Rick Fillion on 11-06-28.
//  Copyright 2011 Centrix.ca. All rights reserved.
//

#import "MKMapView+Private.h"


@implementation MKMapView (Private)

- (void)customInit
{
    // Initialization code here.    
    if (!webView)
    {
        webView = [[MKWebView alloc] initWithFrame:[self bounds]];
    }
    
    [webView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [webView setFrameLoadDelegate:self];
    [webView setUIDelegate:self];
    [webView setMaintainsBackForwardList:NO];
    
    // Create the overlay data structures
    overlays = [[NSMutableArray array] retain];
    overlayViews = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    overlayScriptObjects = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    
    // Create the annotation data structures
    annotations = [[NSMutableArray array] retain];
    selectedAnnotations = [[NSMutableArray array] retain];
    annotationViews = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    annotationScriptObjects = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    
    [self loadMapKitHtml];
    
    // Create a user location
    userLocation = [[MKUserLocation alloc] init];
}

- (void)loadMapKitHtml
{
    // TODO : make this suck less.
    NSBundle *frameworkBundle = [NSBundle bundleForClass:[MKMapView class]];
    NSString *indexPath = [frameworkBundle pathForResource:@"MapKit" ofType:@"html"];
    [[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:indexPath]]]; 
    [[[webView mainFrame] frameView] setAllowsScrolling:NO];
    [self addSubview:webView];
}

@end
