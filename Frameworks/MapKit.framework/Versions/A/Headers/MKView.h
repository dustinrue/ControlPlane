//
//  MKView.h
//  MapKit
//
//  Created by Rick Fillion on 7/19/10.
//  Copyright 2010 Centrix.ca. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface MKView : NSObject {

}

// TODO : might want to rename this one.
@property (nonatomic, readonly) NSString *viewPrototypeName;
@property (nonatomic, readonly) NSDictionary *options;


- (void)draw:(WebScriptObject *)overlayScriptObject;
- (WebScriptObject *)overlayScriptObjectFromMapScriptObject:(WebScriptObject *)mapScriptObject;

@end
