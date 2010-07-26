//
//  MKReverseGeocoder.m
//  MapKit
//
//  Created by Rick Fillion on 7/24/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

/*
 Note:  I'm not particularly proud of this class.  It was mostly coded at 1am with a "fuck, just get it working" attitude.
 Things that could use some fixing by someone who wants to use it seriously:
 - Every MKReverseGeocoder loads up a WebView instance.  Just to get access to javascript.  Change it to load one for everyone.
 - There's this weird issue where the window.MKReverseGeocoder object isn't ready when I want it.  That's why there's the 0.5 sec delay.
 */

#import "MKReverseGeocoder.h"
#import "JSON.h"
#import "MKPlacemark+Private.h"


@interface MKReverseGeocoder (WebViewIntegration)

- (void)didSucceedWithAddress:(id)address;
- (void)didFailWithError:(NSString *)status;

@end


@interface MKReverseGeocoder (Private)

- (void)createWebView;
- (void)destroyWebView;
- (void)_start;

@end


@implementation MKReverseGeocoder

@synthesize delegate;
@synthesize coordinate;
@synthesize placemark;
@synthesize querying;

+ (NSString *) webScriptNameForSelector:(SEL)sel
{
    NSString *name = nil;
    
    if (sel == @selector(didSucceedWithAddress:))
    {
        name = @"didSucceedWithAddress";
    }
    
    if (sel == @selector(didFailWithError:))
    {
        name = @"didFailWithError";
    }

    
    return name;
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector
{
    if (aSelector == @selector(didSucceedWithAddress:))
    {
        return NO;
    }
    
    if (aSelector == @selector(didFailWithError:))
    {
        return NO;
    }

    return YES;
}



- (id)initWithCoordinate:(CLLocationCoordinate2D)aCoordinate
{
    if (self = [super init])
    {
        [self createWebView];
        coordinate = aCoordinate;
    }
    return self;
}

- (void)dealloc
{
    [placemark release];
    [self destroyWebView];
    [super dealloc];
}


- (void)start
{
    if (querying)
        return;
    querying = YES;
    if (webViewLoaded)
        [self performSelector:@selector(_start) withObject:nil afterDelay:0.5];
}

- (void)cancel
{
    if (!querying)
        return;
    querying = NO;
}

#pragma mark WebViewIntegration

- (void)didSucceedWithAddress:(NSString *)jsonAddress
{
    //NSLog(@"didSucceedWithAddress: %@", jsonAddress);
    if (!querying)
        return;
    
    id result = [jsonAddress JSONValue];
    MKPlacemark *aPlacemark = [[[MKPlacemark alloc] initWithGoogleGeocoderResult: result] autorelease];
    placemark = [aPlacemark retain];
    
    if (delegate && [delegate respondsToSelector:@selector(reverseGeocoder:didFindPlacemark:)])
    {
        [delegate reverseGeocoder:self didFindPlacemark:self.placemark];
    }
    querying = NO;
}

- (void)didFailWithError:(NSString *)domain
{
    //NSLog(@"didFailWithErorr: %@", domain);
    if (!querying)
        return;
    
    NSError *error = [NSError errorWithDomain:domain code:0 userInfo:nil];
    // TODO create error
    
    if (delegate && [delegate respondsToSelector:@selector(reverseGeocoder:didFailWithError:)])
    {
        [delegate reverseGeocoder:self didFailWithError:error];
    }
    querying = NO;
}

#pragma mark WebFrameLoadDelegate

- (void)webView:(WebView *)sender didClearWindowObject:(WebScriptObject *)windowScriptObject forFrame:(WebFrame *)frame
{
    //NSLog(@"didClearWindowObjet");
    [windowScriptObject setValue:self forKey:@"MKReverseGeocoder"];
}


- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    //NSLog(@"didFinishLoad:");
    [[webView windowScriptObject] setValue:self forKey:@"MKReverseGeocoder"];
    webViewLoaded = YES;
    if (self.querying)
        [self performSelector:@selector(_start) withObject:nil afterDelay:0.5];
}

#pragma mark Private

- (void)createWebView
{
    if (webView == nil)
    {
        // create it
        // TODO : make this suck less.
        NSBundle *frameworkBundle = [NSBundle bundleForClass:[self class]];
        NSString *indexPath = [frameworkBundle pathForResource:@"MapKit" ofType:@"html"];
        webView = [[WebView alloc] initWithFrame:NSZeroRect frameName:nil groupName:nil];
        [[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:indexPath]]]; 
        [webView autorelease];
        [[webView windowScriptObject] setValue:self forKey:@"MKReverseGeocoder"];
        [webView setFrameLoadDelegate:self];
    }
    [webView retain];
}
- (void)destroyWebView
{
    NSInteger count = [webView retainCount];
    [webView release];
    if (count <= 1)
        webView = nil;
}

- (void)_start
{
    //NSLog(@"start");
    NSArray *args = [NSArray arrayWithObjects:
                     [NSNumber numberWithDouble:coordinate.latitude],
                     [NSNumber numberWithDouble:coordinate.longitude],
                     self,
                     nil];
    WebScriptObject *webScriptObject = [webView windowScriptObject];
    //NSLog(@"got webscriptobject");
    id val = [webScriptObject callWebScriptMethod:@"reverseGeocode" withArguments:args];
    //NSLog(@"val = %@", val);
    if (!val)
    {
        // something went wrong, call the failure delegate
        [self didFailWithError:@"MKErrorDomain"];
    }
}


@end
