//
//  MKMapView.m
//  MapPrototype
//
//  Created by Rick Fillion on 7/11/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import "MKMapView.h"
#import "JSON.h"
#import "MKUserLocation.h"
#import "MKUserLocation+Private.h"
#import "MKCircleView.h"
#import "MKCircle.h"
#import "MKPolyline.h"
#import "MKPolygon.h"

@interface MKMapView (Private)

// delegate wrappers
- (void)delegateRegionWillChangeAnimated:(BOOL)animated;
- (void)delegateRegionDidChangeAnimated:(BOOL)animated;
- (void)delegateDidUpdateUserLocation;
- (void)delegateDidFailToLocateUserWithError:(NSError *)error;
- (void)delegateWillStartLocatingUser;
- (void)delegateDidStopLocatingUser;
- (void)delegateDidAddOverlayViews:(NSArray *)overlayViews;

// WebView integration
- (void)setUserLocationMarkerVisible:(BOOL)visible;
- (void)updateUserLocationMarkerWithLocaton:(CLLocation *)location;

@end


@implementation MKMapView

@synthesize delegate, mapType, showsUserLocation;

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        overlays = [[NSMutableArray array] retain];
        // Initialization code here.
        webView = [[WebView alloc] initWithFrame:[self bounds]];
        [webView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [webView setFrameLoadDelegate:self];
        
        // TODO : make this suck less.
        NSBundle *frameworkBundle = [NSBundle bundleForClass:[self class]];
        NSString *indexPath = [frameworkBundle pathForResource:@"index" ofType:@"html"];
        [[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:indexPath]]]; 
        [[[webView mainFrame] frameView] setAllowsScrolling:NO];
        [self addSubview:webView];
        
        // Create a user location
        userLocation = [MKUserLocation new];
        
        // Get CoreLocation Manager
        locationManager = [CLLocationManager new];
        locationManager.delegate = self;
        locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        
    }
    return self;
}

- (void)dealloc
{
    [webView removeFromSuperview];
    [webView release];
    [locationManager stopUpdatingLocation];
    [locationManager release];
    [userLocation release];
    [overlays release];
    [super dealloc];
}

- (void)setFrame:(NSRect)frameRect
{
    [self delegateRegionWillChangeAnimated:NO];
    [super setFrame:frameRect];
    [self willChangeValueForKey:@"region"];
    [self didChangeValueForKey:@"region"];
    [self willChangeValueForKey:@"centerCoordinate"];
    [self didChangeValueForKey:@"centerCoordinate"];
    [self delegateRegionDidChangeAnimated:NO];
}

- (void)setMapType:(MKMapType)type
{
    mapType = type;
    WebScriptObject *webScriptObject = [webView windowScriptObject];
    NSArray *args = [NSArray arrayWithObject:[NSNumber numberWithInt:mapType]];
    [webScriptObject callWebScriptMethod:@"setMapType" withArguments:args];
}

- (CLLocationCoordinate2D)centerCoordinate
{
    WebScriptObject *webScriptObject = [webView windowScriptObject];
    NSString *json = [webScriptObject evaluateWebScript:@"getCenterCoordinate()"];
    NSDictionary *latlong = [json MKJSONValue];
    NSNumber *latitude = [latlong objectForKey:@"latitude"];
    NSNumber *longitude = [latlong objectForKey:@"longitude"];

    CLLocationCoordinate2D centerCoordinate;
    centerCoordinate.latitude = [latitude doubleValue];
    centerCoordinate.longitude = [longitude doubleValue];
    return centerCoordinate;
}

- (void)setCenterCoordinate:(CLLocationCoordinate2D)coordinate
{
    [self setCenterCoordinate:coordinate animated: NO];
}

- (void)setCenterCoordinate:(CLLocationCoordinate2D)coordinate animated:(BOOL)animated
{
    [self willChangeValueForKey:@"region"];
    NSArray *args = [NSArray arrayWithObjects:
                     [NSNumber numberWithDouble:coordinate.latitude],
                     [NSNumber numberWithDouble:coordinate.longitude],
                     [NSNumber numberWithBool:animated], 
                      nil];
    WebScriptObject *webScriptObject = [webView windowScriptObject];
    [webScriptObject callWebScriptMethod:@"setCenterCoordinateAnimated" withArguments:args];
    [self didChangeValueForKey:@"region"];
}


- (MKCoordinateRegion)region
{
    WebScriptObject *webScriptObject = [webView windowScriptObject];
    NSString *json = [webScriptObject evaluateWebScript:@"getRegion()"];
    NSDictionary *regionDict = [json MKJSONValue];
    
    NSNumber *centerLatitude = [regionDict valueForKeyPath:@"center.latitude"];
    NSNumber *centerLongitude = [regionDict valueForKeyPath:@"center.longitude"];
    NSNumber *latitudeDelta = [regionDict objectForKey:@"latitudeDelta"];
    NSNumber *longitudeDelta = [regionDict objectForKey:@"longitudeDelta"];
    
    MKCoordinateRegion region;
    region.center.longitude = [centerLongitude doubleValue];
    region.center.latitude = [centerLatitude doubleValue];
    region.span.latitudeDelta = [latitudeDelta doubleValue];
    region.span.longitudeDelta = [longitudeDelta doubleValue];
    return region;
}

- (void)setRegion:(MKCoordinateRegion)region
{
    [self setRegion:region animated: NO];
}

- (void)setRegion:(MKCoordinateRegion)region animated:(BOOL)animated
{
    [self delegateRegionWillChangeAnimated:animated];
    [self willChangeValueForKey:@"centerCoordinate"];
    WebScriptObject *webScriptObject = [webView windowScriptObject];
    NSArray *args = [NSArray arrayWithObjects:
                     [NSNumber numberWithDouble:region.center.latitude], 
                     [NSNumber numberWithDouble:region.center.longitude], 
                     [NSNumber numberWithDouble:region.span.latitudeDelta], 
                     [NSNumber numberWithDouble:region.span.longitudeDelta],
                     [NSNumber numberWithBool:animated], 
                     nil];
    [webScriptObject callWebScriptMethod:@"setRegionAnimated" withArguments:args];
    [self didChangeValueForKey:@"centerCoordinate"];
    [self delegateRegionDidChangeAnimated:animated];
}

- (void)setShowsUserLocation:(BOOL)show
{
    if (show == showsUserLocation)
        return;
    showsUserLocation = show;
    if (showsUserLocation)
    {
        [userLocation _setUpdating:YES];
        [locationManager startUpdatingLocation];
    }
    else 
    {
        [self setUserLocationMarkerVisible: NO];
        [userLocation _setUpdating:NO];
        [locationManager stopUpdatingLocation];
        [userLocation _setLocation:nil];
    }
}

- (BOOL)isUserLocationVisible
{
    if (!self.showsUserLocation || !userLocation.location)
        return NO;
    WebScriptObject *webScriptObject = [webView windowScriptObject];
    NSNumber *visible = [webScriptObject callWebScriptMethod:@"isUserLocationVisible" withArguments:[NSArray array]];
    return [visible boolValue];
}

#pragma mark Overlays

- (NSArray *)overlays
{
    return [[overlays copy] autorelease];
}

- (void)addOverlay:(id < MKOverlay >)overlay
{
//TODO
    WebScriptObject *webScriptObject = [webView windowScriptObject];
    
    MKOverlayView *overlayView = nil;
    if ([self.delegate respondsToSelector:@selector(mapView:viewForOverlay:)])
        overlayView = [self.delegate mapView:self viewForOverlay:overlay];
    if (!overlayView)
    {
        // TODO: Handle the case where we have no view
    }
    
    WebScriptObject *overlayObject = [overlayView overlayScriptObjectFromMapSriptObject:webScriptObject];
    NSArray *args = [NSArray arrayWithObject:overlayObject];
    [webScriptObject callWebScriptMethod:@"addOverlay" withArguments:args];
    [overlayView draw:overlayObject];
    [self delegateDidAddOverlayViews:[NSArray arrayWithObject:overlayView]];
}

- (void)addOverlays:(NSArray *)someOverlays
{
    for (id<MKOverlay>overlay in someOverlays)
    {
        [self addOverlay: overlay];
    }
}

- (void)exchangeOverlayAtIndex:(NSUInteger)index1 withOverlayAtIndex:(NSUInteger)index2
{
    //TODO
}

- (void)insertOverlay:(id < MKOverlay >)overlay aboveOverlay:(id < MKOverlay >)sibling
{
    //TODO
}

- (void)insertOverlay:(id < MKOverlay >)overlay atIndex:(NSUInteger)index
{
    //TODO
}

- (void)insertOverlay:(id < MKOverlay >)overlay belowOverlay:(id < MKOverlay >)sibling
{
    //TODO
}

- (void)removeOverlay:(id < MKOverlay >)overlay
{
    //TODO
}

- (void)removeOverlays:(NSArray *)someOverlays
{
    for (id<MKOverlay>overlay in someOverlays)
    {
        [self removeOverlay: overlay];
    }
}

- (MKOverlayView *)viewForOverlay:(id < MKOverlay >)overlay
{
    //TODO
    return nil;
}


#pragma mark Faked Properties

- (BOOL)isScrollEnabled
{
    return YES;
}

- (void)setScrollEnabled:(BOOL)scrollEnabled
{
    if (!scrollEnabled)
        NSLog(@"setting scrollEnabled to NO on MKMapView not supported.");
}

- (BOOL)isZoomEnabled
{
    return YES;
}

- (void)setZoomEnabled:(BOOL)zoomEnabled
{
    if (!zoomEnabled)
        NSLog(@"setting zoomEnabled to NO on MKMapView not supported");
}



#pragma mark CoreLocationManagerDelegate

- (void) locationManager: (CLLocationManager *)manager
     didUpdateToLocation: (CLLocation *)newLocation
            fromLocation: (CLLocation *)oldLocation
{
    [self setCenterCoordinate:newLocation.coordinate];
    [userLocation _setLocation:newLocation];
    [self updateUserLocationMarkerWithLocaton:newLocation];
    [self setUserLocationMarkerVisible:YES];
    [self delegateDidUpdateUserLocation];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    [self delegateDidFailToLocateUserWithError:error];
    [self setUserLocationMarkerVisible:NO];
}

#pragma mark WebFrameLoadDelegate

#pragma mark WebFrameLoadDelegate

- (void)webView:(WebView *)sender didClearWindowObject:(WebScriptObject *)windowScriptObject forFrame:(WebFrame *)frame
{
    [windowScriptObject setValue:windowScriptObject forKey:@"WindowScriptObject"];
}


- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    // CoreLocation can sometimes trigger before the page has even finished loading.
    if (self.showsUserLocation && userLocation.location)
    {
        [self locationManager: locationManager didUpdateToLocation: userLocation.location fromLocation:nil];
    }
    
    CLLocationCoordinate2D coord;
    coord.latitude = 49.84770356304121;
    coord.longitude = -97.1728089768459;
    MKCircle *circle = [MKCircle circleWithCenterCoordinate:coord radius: 400];
//    [self addOverlay: circle];

    CLLocationCoordinate2D coords[3];
    coords[0].latitude = 49.83770356304121;
    coords[0].longitude = -97.1628089768459;
    coords[1].latitude = 49.86770356304121;
    coords[1].longitude = -97.1628089768459;
    coords[2].latitude = 49.86770356304121;
    coords[2].longitude = -97.2028089768459;
    
    CLLocationCoordinate2D innerCoords[3];
    innerCoords[0].latitude = 49.85070356304121;
    innerCoords[0].longitude = -97.1758089768459;
    innerCoords[1].latitude = 49.85470356304121;
    innerCoords[1].longitude = -97.1758089768459;
    innerCoords[2].latitude = 49.85470356304121;
    innerCoords[2].longitude = -97.1828089768459;
    
    MKPolyline *polyline = [MKPolyline polylineWithCoordinates:coords count:3];
    MKPolygon *innerPolygon = [MKPolygon polygonWithCoordinates:innerCoords count:3];
    MKPolygon *polygon = [MKPolygon polygonWithCoordinates:coords count:3 interiorPolygons:[NSArray arrayWithObject:innerPolygon]];

    [self addOverlay: polygon];
}


#pragma mark Private Delegate Wrappers

- (void)delegateRegionWillChangeAnimated:(BOOL)animated
{
    if (delegate && [delegate respondsToSelector:@selector(mapView:regionWillChangeAnimated:)])
    {
        [delegate mapView:self regionWillChangeAnimated:animated];
    }
}

- (void)delegateRegionDidChangeAnimated:(BOOL)animated
{
    if (delegate && [delegate respondsToSelector:@selector(mapView:regionDidChangeAnimated:)])
    {
        [delegate mapView:self regionDidChangeAnimated:animated];
    }
}

- (void)delegateDidUpdateUserLocation
{
    if (delegate && [delegate respondsToSelector:@selector(mapView:didUpdateUserLocation:)])
    {
        [delegate mapView:self didUpdateUserLocation:userLocation];
    }
}

- (void)delegateDidFailToLocateUserWithError:(NSError *)error
{
    if (delegate && [delegate respondsToSelector:@selector(mapView:didFailToLocateUserWithError:)])
    {
        [delegate mapView:self didFailToLocateUserWithError:error];
    }
}

- (void)delegateWillStartLocatingUser
{
    if (delegate && [delegate respondsToSelector:@selector(mapViewWillStartLocatingUser:)])
    {
        [delegate mapViewWillStartLocatingUser:self];
    }
}

- (void)delegateDidStopLocatingUser
{
    if (delegate && [delegate respondsToSelector:@selector(mapViewDidStopLocatingUser:)])
    {
        [delegate mapViewDidStopLocatingUser:self];
    }
}

- (void)delegateDidAddOverlayViews:(NSArray *)overlayViews
{
    if (delegate && [delegate respondsToSelector:@selector(mapView:didAddOverlayViews:)])
    {
        [delegate mapView:self didAddOverlayViews:overlayViews];
    }
}

#pragma mark Private WebView Integration

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

@end
