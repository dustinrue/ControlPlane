//
//  MKOverlayView.h
//  MapPrototype
//
//  Created by Rick Fillion on 7/12/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "MKOverlay.h"


@interface MKOverlayView : NSObject {
    id <MKOverlay> overlay;
}

@property (nonatomic, readonly) id <MKOverlay> overlay;
// TODO : might want to rename this one.
@property (nonatomic, readonly) NSString *objectName;
@property (nonatomic, readonly) NSDictionary *options;

- (id)initWithOverlay:(id <MKOverlay>)anOverlay;

- (void)draw:(WebScriptObject *)overlayScriptObject;// withWindowScriptObject:(WebScriptObject *)windowScriptObject;
- (WebScriptObject *)overlayScriptObjectFromMapSriptObject:(WebScriptObject *)mapScriptObject;

@end
