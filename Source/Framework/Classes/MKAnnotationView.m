//
//  MKAnnotationView.m
//  MapKit
//
//  Created by Rick Fillion on 7/18/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import "MKAnnotationView.h"


@implementation MKAnnotationView

@synthesize reuseIdentifier;
@synthesize annotation;
@synthesize image;
@synthesize centerOffset;
@synthesize calloutOffset;
@synthesize enabled;
@synthesize highlighted;
@synthesize selected;
@synthesize canShowCallout;
 

- (id)initWithAnnotation:(id <MKAnnotation>)anAnnotation reuseIdentifier:(NSString *)aReuseIdentifier
{
    if (self = [super init])
    {
        reuseIdentifier = [aReuseIdentifier retain];
        self.annotation = anAnnotation;
    }
    return self;
}

- (void)dealloc
{
    [reuseIdentifier release];
    [(id)annotation release];
    [super dealloc];
}

- (void)prepareForReuse
{
}

- (void)setSelected:(BOOL)_selected animated:(BOOL)animated
{
    self.selected = _selected;
}

@end
