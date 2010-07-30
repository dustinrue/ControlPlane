//
//  MKMapViewIntegration.m
//  MapKit
//
//  Created by Rick Fillion on 7/26/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import <InterfaceBuilderKit/InterfaceBuilderKit.h>
#import <MapKit/MKMapView.h>
#import "MapKitPluginInspector.h"

@implementation MKMapView ( MapKitPlugin )

- (void)ibPopulateKeyPaths:(NSMutableDictionary *)keyPaths {
    [super ibPopulateKeyPaths:keyPaths];
	
	// Remove the comments and replace "MyFirstProperty" and "MySecondProperty" 
	// in the following line with a list of your view's KVC-compliant properties.
    //[[keyPaths objectForKey:IBAttributeKeyPaths] addObjectsFromArray:[NSArray arrayWithObjects:/* @"MyFirstProperty", @"MySecondProperty",*/ nil]];
}

- (void)ibPopulateAttributeInspectorClasses:(NSMutableArray *)classes {
    [super ibPopulateAttributeInspectorClasses:classes];
    //[classes addObject:[MapKitPluginInspector class]];
}

@end
