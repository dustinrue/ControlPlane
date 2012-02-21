//
//  MKPointAnnotation.m
//  MapKit
//
//  Created by Rick Fillion on 7/18/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import "MKPointAnnotation.h"


@implementation MKPointAnnotation

@synthesize coordinate;

- (NSString *)description
{
    NSString *superDescription = [super description];
    return [superDescription stringByAppendingFormat:@" <%f, %f> %@ - %@", self.coordinate.latitude, self.coordinate.longitude, self.title, self.subtitle];
}

@end
