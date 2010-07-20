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

- (NSString *)imageUrl
{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
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

- (void)setAnimatesDrop:(BOOL)animates
{
    if (animates)
    {
        // TODO : figure out a way to animate this in.
        NSLog(@"animatesDrop isn't supported in this version.");
    }
}

@end
