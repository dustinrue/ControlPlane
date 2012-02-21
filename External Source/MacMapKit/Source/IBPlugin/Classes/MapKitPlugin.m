//
//  MapKitPlugin.m
//  MapKit
//
//  Created by Rick Fillion on 7/26/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import "MapKitPlugin.h"


@implementation MapKitPlugin

- (NSArray *)libraryNibNames {
    return [NSArray arrayWithObject:@"MapKitPluginLibrary"];
}

- (NSArray *)requiredFrameworks {
    return [NSArray arrayWithObjects:[NSBundle bundleWithIdentifier:@"ca.centrix.MapKitFramework"], nil];
}

- (NSString *)label
{
    return @"Map Kit";
}

@end
