//
//  MKShape.h
//  MapPrototype
//
//  Created by Rick Fillion on 7/12/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MKAnnotation.h"

@interface MKShape : NSObject <MKAnnotation> {
    CLLocationCoordinate2D coordinate;
    NSString *title;
    NSString *subtitle;
}

@property (copy) NSString *title;
@property (copy) NSString *subtitle;
@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;


@end
