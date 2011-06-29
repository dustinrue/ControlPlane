//
//  MKMapView+WebViewIntegration.m
//  MapKit
//
//  Created by Rick Fillion on 7/22/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import "MKMapView+WebViewIntegration.h"
#import "MKMapView+DelegateWrappers.h"
#import "JSON.h"
#import "MKWebView.h"
#import "MKMapView+Private.h"


@implementation MKMapView (WebViewIntegration)

+ (NSString *) webScriptNameForSelector:(SEL)sel
{
    NSString *name = nil;
    
    if (sel == @selector(annotationScriptObjectSelected:))
    {
        name = @"annotationScriptObjectSelected";
    }
    
    if (sel == @selector(webviewReportingRegionChange))
    {
        name = @"webviewReportingRegionChange";
    }
    
    if (sel == @selector(webviewReportingLoadFailure))
    {
        name = @"webviewReportingLoadFailure";
    }

    if (sel == @selector(webviewReportingClick:))
    {
        name = @"webviewReportingClick";
    }
    
    if (sel == @selector(webviewReportingReloadGmaps))
    {
	name = @"webviewReportingReloadGmaps";
    }
        
    if (sel == @selector(annotationScriptObjectDragStart:))
    {
        name = @"annotationScriptObjectDragStart";
    }
    
    if (sel == @selector(annotationScriptObjectDrag:))
    {
        name = @"annotationScriptObjectDrag";
    }
    
    if (sel == @selector(annotationScriptObjectDragEnd:))
    {
        name = @"annotationScriptObjectDragEnd";
    }
    
    if (sel == @selector(annotationScriptObjectRightClick:))
    {
	name = @"annotationScriptObjectRightClick";
    }
    
    return name;
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector
{
    if (aSelector == @selector(annotationScriptObjectSelected:))
    {
        return NO;
    }
    
    if (aSelector == @selector(webviewReportingRegionChange))
    {
        return NO;
    }
    
    if (aSelector == @selector(webviewReportingLoadFailure))
    {
        return NO;
    }
    
    if (aSelector == @selector(webviewReportingClick:))
    {
        return NO;
    }
    
    if (aSelector == @selector(webviewReportingReloadGmaps))
    {
	return NO;
    }
    
    if (aSelector == @selector(annotationScriptObjectDragStart:))
    {
        return NO;
    }
    
    if (aSelector == @selector(annotationScriptObjectDrag:))
    {
        return NO;
    }
    
    if (aSelector == @selector(annotationScriptObjectDragEnd:))
    {
        return NO;
    }
    
    if (aSelector == @selector(annotationScriptObjectRightClick:))
    {
	return NO;
    }
    
    return YES;
}


- (void)setUserLocationMarkerVisible:(BOOL)visible
{
    NSArray *args = [NSArray arrayWithObjects:
                     [NSNumber numberWithBool:visible], 
                     nil];
    WebScriptObject *webScriptObject = [webView windowScriptObject];
    [webScriptObject callWebScriptMethod:@"setUserLocationVisible" withArguments:args];
    //NSLog(@"calling setUserLocationVisible with %@", args);
}

- (void)updateUserLocationMarkerWithLocaton:(CLLocation *)location
{
    WebScriptObject *webScriptObject = [webView windowScriptObject];
    
    CLLocationAccuracy accuracy = MAX(location.horizontalAccuracy, location.verticalAccuracy);
    NSArray *args = [NSArray arrayWithObjects:
                     [NSNumber numberWithDouble: accuracy], 
                     nil];
    [webScriptObject callWebScriptMethod:@"setUserLocationRadius" withArguments:args];
    //NSLog(@"calling setUserLocationRadius with %@", args);
    args = [NSArray arrayWithObjects:
            [NSNumber numberWithDouble:location.coordinate.latitude],
            [NSNumber numberWithDouble:location.coordinate.longitude],
            nil];
    [webScriptObject callWebScriptMethod:@"setUserLocationLatitudeLongitude" withArguments:args];
    //NSLog(@"caling setUserLocationLatitudeLongitude with %@", args);
}

- (void)updateOverlayZIndexes
{
    //NSLog(@"updating overlay z indexes of :%@", overlays);
    NSUInteger zIndex = 4000; // some arbitrary starting value
    WebScriptObject *webScriptObject = [webView windowScriptObject];
    for (id <MKOverlay> overlay in overlays)
    {
        WebScriptObject *overlayScriptObject = (WebScriptObject *)CFDictionaryGetValue(overlayScriptObjects, overlay);
        if (overlayScriptObject)
        {
            NSArray *args = [NSArray arrayWithObjects: overlayScriptObject, @"zIndex", [NSNumber numberWithInteger:zIndex], nil];
            [webScriptObject callWebScriptMethod:@"setOverlayOption" withArguments:args];
        }
        zIndex++;
    }
}

- (void)updateAnnotationZIndexes
{
    NSUInteger zIndex = 6000; // some arbitrary starting value
    WebScriptObject *webScriptObject = [webView windowScriptObject];
    
    NSArray *sortedAnnotations = [annotations sortedArrayUsingComparator: ^(id <MKAnnotation> ann1, id <MKAnnotation> ann2) {
        if (ann1.coordinate.latitude < ann2.coordinate.latitude) {
            return (NSComparisonResult)NSOrderedDescending;
        }
        
        if (ann1.coordinate.latitude > ann2.coordinate.latitude) {
            return (NSComparisonResult)NSOrderedAscending;
        }
        return (NSComparisonResult)NSOrderedSame;
    }];
    
    for (id <MKAnnotation> annotation in sortedAnnotations)
    {
        WebScriptObject *overlayScriptObject = (WebScriptObject *)CFDictionaryGetValue(annotationScriptObjects, annotation);
        if (overlayScriptObject)
        {
            NSArray *args = [NSArray arrayWithObjects: overlayScriptObject, @"zIndex", [NSNumber numberWithInteger:zIndex], nil];
            [webScriptObject callWebScriptMethod:@"setOverlayOption" withArguments:args];
        }
        zIndex++;
    }
}

- (void)annotationScriptObjectSelected:(WebScriptObject *)annotationScriptObject
{
    // Deselect everything that was selected
    [self setSelectedAnnotations:[NSArray array]];
    
    for (id <MKAnnotation> annotation in annotations)
    {
        WebScriptObject *scriptObject = (WebScriptObject *)CFDictionaryGetValue(annotationScriptObjects, annotation);
        if ([scriptObject isEqual:annotationScriptObject])
        {
            [self selectAnnotation:annotation animated:NO];
        }
    }
}

- (void)annotationScriptObjectDragStart:(WebScriptObject *)annotationScriptObject
{
    //NSLog(@"annotationScriptObjectDragStart:");
    for (id <MKAnnotation> annotation in annotations)
    {
        WebScriptObject *scriptObject = (WebScriptObject *)CFDictionaryGetValue(annotationScriptObjects, annotation);
        if ([scriptObject isEqual:annotationScriptObject])
        {
            // it has to be an annotation that actually supports moving.
            if ([annotation respondsToSelector:@selector(setCoordinate:)])
            {
                MKAnnotationView *view = (MKAnnotationView *)CFDictionaryGetValue(annotationViews, annotation);
                view.dragState = MKAnnotationViewDragStateStarting;
                [self delegateAnnotationView:view didChangeDragState:MKAnnotationViewDragStateStarting fromOldState:MKAnnotationViewDragStateNone];
            }
        }
    }
}

- (void)annotationScriptObjectDrag:(WebScriptObject *)annotationScriptObject
{
    //NSLog(@"annotationScriptObjectDrag:");
    for (id <MKAnnotation> annotation in annotations)
    {
        WebScriptObject *scriptObject = (WebScriptObject *)CFDictionaryGetValue(annotationScriptObjects, annotation);
        if ([scriptObject isEqual:annotationScriptObject])
        {
            // it has to be an annotation that actually supports moving.
            if ([annotation respondsToSelector:@selector(setCoordinate:)])
            {
                CLLocationCoordinate2D newCoordinate = [self coordinateForAnnotationScriptObject:annotationScriptObject];
                [(id)annotation setCoordinate:newCoordinate];
                MKAnnotationView *view = (MKAnnotationView *)CFDictionaryGetValue(annotationViews, annotation);
                if (view.dragState != MKAnnotationViewDragStateDragging)
                {
                    view.dragState = MKAnnotationViewDragStateNone;
                    [self delegateAnnotationView:view didChangeDragState:MKAnnotationViewDragStateDragging fromOldState:MKAnnotationViewDragStateStarting];
                }
            }
        }
    }
}

- (void)annotationScriptObjectDragEnd:(WebScriptObject *)annotationScriptObject
{
    //NSLog(@"annotationScriptObjectDragEnd");
    for (id <MKAnnotation> annotation in annotations)
    {
        WebScriptObject *scriptObject = (WebScriptObject *)CFDictionaryGetValue(annotationScriptObjects, annotation);
        if ([scriptObject isEqual:annotationScriptObject])
        {
            // it has to be an annotation that actually supports moving.
            if ([annotation respondsToSelector:@selector(setCoordinate:)])
            {
                CLLocationCoordinate2D newCoordinate = [self coordinateForAnnotationScriptObject:annotationScriptObject];
                [(id)annotation setCoordinate:newCoordinate];
                MKAnnotationView *view = (MKAnnotationView *)CFDictionaryGetValue(annotationViews, annotation);
                view.dragState = MKAnnotationViewDragStateNone;
                [self delegateAnnotationView:view didChangeDragState:MKAnnotationViewDragStateNone fromOldState:MKAnnotationViewDragStateDragging];
            }
        }
    }
}

- (void)webviewReportingRegionChange
{
    [self delegateRegionDidChangeAnimated:NO];
    [self willChangeValueForKey:@"centerCoordinate"];
    [self didChangeValueForKey:@"centerCoordinate"];
    [self willChangeValueForKey:@"region"];
    [self didChangeValueForKey:@"region"];
}

- (void)webviewReportingLoadFailure
{
    NSError *error = [NSError errorWithDomain:@"ca.centrix.MapKit" code:0 userInfo:nil];
    [self delegateDidFailLoadingMapWithError:error];
}

- (void)webviewReportingClick:(NSString *)jsonEncodedLatLng
{
    // Deselect all annoations
    NSArray * currentlySelectedAnnotations = [self selectedAnnotations];
    for (id <MKAnnotation> annotation in currentlySelectedAnnotations)
    {
        [self deselectAnnotation:annotation animated:YES];
    }

    // Give the delegate the opportunity to do something
    // if the clicked and held for more than 0.5 secs.
    NSTimeInterval timeSinceMouseDown = [[NSDate date] timeIntervalSinceDate:[webView lastHitTestDate]];
    if (timeSinceMouseDown > 0.5)
    {
        NSDictionary *latlong = [jsonEncodedLatLng JSONValue];
        NSNumber *latitude = [latlong objectForKey:@"latitude"];
        NSNumber *longitude = [latlong objectForKey:@"longitude"];
        CLLocationCoordinate2D coordinate;
        coordinate.latitude = [latitude doubleValue];
        coordinate.longitude = [longitude doubleValue];
        [self delegateUserDidClickAndHoldAtCoordinate:coordinate];
    }
}

- (void)webviewReportingReloadGmaps
{
    [self loadMapKitHtml];
}

- (void)annotationScriptObjectRightClick:(WebScriptObject *)annotationScriptObject
{
    //NSLog(@"annotationScriptObjectRightClick");

    // Find the actual MKAnnotationView
    MKAnnotationView *annotationView = nil;
    for (id <MKAnnotation> annotation in annotations)
    {
        WebScriptObject *scriptObject = (WebScriptObject *)CFDictionaryGetValue(annotationScriptObjects, annotation);
        if ([scriptObject isEqual:annotationScriptObject])
        {
	    annotationView = (MKAnnotationView *)CFDictionaryGetValue(annotationViews, annotation);
        }
    }
    
    // If not found, bail.
    if (!annotationView)
	return;
    
    
    // Create a corresponding NSEvent object so that we can popup a context menu
    NSPoint pointOnScreen = [NSEvent mouseLocation];
    NSPoint pointInBase = [[self window] convertScreenToBase: pointOnScreen];
    
    NSEvent *event = [NSEvent mouseEventWithType:NSRightMouseUp  
                                        location:pointInBase
				   modifierFlags:[NSEvent modifierFlags]
				       timestamp:0
				    windowNumber:[[self window] windowNumber] 
					 context:[NSGraphicsContext currentContext]
				     eventNumber:0
				      clickCount:1 
					pressure:1.0];
    
    // Create the menu and display it if it has anything.
    NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
    NSArray *items = [self delegateContextMenuItemsForAnnotationView:annotationView];
    if ([items count] > 0)
    {
	for (NSMenuItem *item in items)
	{
	    [menu addItem:item];
	}
	[NSMenu popUpContextMenu:menu withEvent:event forView:self];	
    }
}

- (CLLocationCoordinate2D)coordinateForAnnotationScriptObject:(WebScriptObject *)annotationScriptObject
{
    CLLocationCoordinate2D coord;
    coord.latitude = 0.0;
    coord.longitude = 0.0;
    WebScriptObject *windowScriptObject = [webView windowScriptObject];
    
    NSString *json = [windowScriptObject callWebScriptMethod:@"coordinateForAnnotation" withArguments:[NSArray arrayWithObject:annotationScriptObject]];
    NSDictionary *latlong = [json JSONValue];
    NSNumber *latitude = [latlong objectForKey:@"latitude"];
    NSNumber *longitude = [latlong objectForKey:@"longitude"];
    
    coord.latitude = [latitude doubleValue];
    coord.longitude = [longitude doubleValue];
    
    return coord;
}


@end
