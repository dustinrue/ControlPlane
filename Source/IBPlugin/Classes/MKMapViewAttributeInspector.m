//
//  MapKitPluginInspector.m
//  MapKit
//
//  Created by Rick Fillion on 7/26/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import "MKMapViewAttributeInspector.h"


@implementation MKMapViewAttributeInspector

- (NSString *)viewNibName {
	return @"MKMapViewAttributeInspector";
}

- (NSString *)label
{
    return @"Map View";
}

- (void)awakeFromNib
{

}

- (void)refresh {
	// Synchronize your inspector's content view with the currently selected objects.
	[super refresh];
}

@end
