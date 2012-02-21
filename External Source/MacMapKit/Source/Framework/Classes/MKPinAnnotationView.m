//
//  MKPinAnnotationView.m
//  MapKit
//
//  Created by Rick Fillion on 7/18/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import "MKPinAnnotationView.h"


@implementation MKPinAnnotationView

@synthesize pinColor;
@synthesize animatesDrop;

- (id)initWithAnnotation:(id <MKAnnotation>)anAnnotation reuseIdentifier:(NSString *)aReuseIdentifier
{
    if (self = [super initWithAnnotation:anAnnotation reuseIdentifier:aReuseIdentifier])
    {
        self.canShowCallout = YES;
    }
    return self;
}

- (NSString *)imageUrl
{
    NSBundle *bundle = [NSBundle bundleForClass:[MKPinAnnotationView class]];
    NSString *filename = nil;
    switch (pinColor) {
        case MKPinAnnotationColorRed:
            filename = @"MKPinAnnotationColorRed";
            break;
        case MKPinAnnotationColorGreen:
            filename = @"MKPinAnnotationColorGreen";
            break;
        case MKPinAnnotationColorPurple:
            filename = @"MKPinAnnotationColorPurple";
            break;
        default:
            filename = @"MKPinAnnotationColorRed";
            break;
    }
    NSString *path = [bundle pathForResource:filename ofType:@"png"];
    NSURL *url = [NSURL fileURLWithPath:path];
    return [url absoluteString];
}

@end
