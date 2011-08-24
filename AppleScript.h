//
//  AppleScript.h
//  ControlPlane
//
//  Created by David Jennes on 24/08/11.
//  Copyright 2011. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface NSApplication (AppleScript)

- (NSString *) currentContext;
- (void) setCurrentContext: (NSString*) newContext;

- (NSNumber *) sticky;
- (void) setSticky: (NSNumber *) sticky;

@end
