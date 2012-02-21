//
//  MKWebView.m
//  MapKit
//
//  Created by Rick Fillion on 10-12-12.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import "MKWebView.h"


@implementation MKWebView

@synthesize lastHitTestDate;

- (void)dealloc
{
    [lastHitTestDate release];
    [super dealloc];
}

- (NSView *)hitTest:(NSPoint)aPoint
{
    //NSLog(@"hitTest: %@", NSStringFromPoint(aPoint));
    [lastHitTestDate release];
    lastHitTestDate = [[NSDate date] retain];
    return [super hitTest:aPoint];
}

@end
