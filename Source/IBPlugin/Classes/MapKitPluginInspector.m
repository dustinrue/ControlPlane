//
//  MapKitPluginInspector.m
//  MapKit
//
//  Created by Rick Fillion on 7/26/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import "MapKitPluginInspector.h"


@implementation MapKitPluginInspector

- (NSString *)viewNibName {
	return @"MapKitPluginInspector";
}

- (void)refresh {
	// Synchronize your inspector's content view with the currently selected objects.
	[super refresh];
}

@end
