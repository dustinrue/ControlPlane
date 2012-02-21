//
//  MKAnnotationView.h
//  MapKit
//
//  Created by Rick Fillion on 7/18/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MapKit/MKView.h>
#import <WebKit/WebKit.h>

enum {
    MKAnnotationViewDragStateNone = 0,      // View is at rest, sitting on the map.
    MKAnnotationViewDragStateStarting,      // View is beginning to drag (e.g. pin lift)
    MKAnnotationViewDragStateDragging,      // View is dragging ("lift" animations are complete)
    MKAnnotationViewDragStateCanceling,     // View was not dragged and should return to it's starting position (e.g. pin drop)
    MKAnnotationViewDragStateEnding         // View was dragged, new coordinate is set and view should return to resting position (e.g. pin drop)
};

typedef NSUInteger MKAnnotationViewDragState;

@protocol MKAnnotation;


@interface MKAnnotationView : MKView {
    NSString *reuseIdentifier;
    id <MKAnnotation> annotation;
    NSString *imageUrl;
    CGPoint centerOffset;
    CGPoint calloutOffset;
    BOOL enabled;
    BOOL highlighted;
    BOOL selected;
    BOOL canShowCallout;
    BOOL draggable;
    MKAnnotationViewDragState dragState;
@private
    WebScriptObject *markerImage;
    WebScriptObject *latlngCenter;
}

- (id)initWithAnnotation:(id <MKAnnotation>)annotation reuseIdentifier:(NSString *)reuseIdentifier;

@property (nonatomic, readonly) NSString *reuseIdentifier;
// Classes that override must call super.
- (void)prepareForReuse;

@property (nonatomic, retain) id <MKAnnotation> annotation;

@property (nonatomic, copy) NSString *imageUrl;

// By default, the center of annotation view is placed over the coordinate of the annotation.
// centerOffset is the offset in pixels from the center of the annotion view.
@property (nonatomic) CGPoint centerOffset;

// calloutOffset is the offset in pixels from the top-middle of the annotation view, where the anchor of the callout should be shown.
@property (nonatomic) CGPoint calloutOffset;

// Defaults to YES. If NO, ignores touch events and subclasses may draw differently.
@property (nonatomic, getter=isEnabled) BOOL enabled;

// Defaults to NO. This gets set/cleared automatically when touch enters/exits during tracking and cleared on up.
@property (nonatomic, getter=isHighlighted) BOOL highlighted;

// Defaults to NO. Becomes YES when tapped on in the map view.
@property (nonatomic, getter=isSelected) BOOL selected;
- (void)setSelected:(BOOL)selected animated:(BOOL)animated;

// If YES, a standard callout bubble will be shown when the annotation is selected.
// The annotation must have a title for the callout to be shown.
@property (nonatomic) BOOL canShowCallout;


// If YES and the underlying id<MKAnnotation> responds to setCoordinate:, 
// the user will be able to drag this annotation view around the map.
@property (nonatomic, getter=isDraggable) BOOL draggable;

// Automatically set to MKAnnotationViewDragStateStarting, Canceling, and Ending when necessary.
// Implementer is responsible for transitioning to Dragging and None states as appropriate.
@property (nonatomic) MKAnnotationViewDragState dragState;


@end
