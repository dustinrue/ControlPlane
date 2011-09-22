//
//  Source.h
//  ControlPlane
//
//  Created by David Jennes on 18/09/11.
//  Copyright 2011. All rights reserved.
//

@class Rule;

@interface Source : NSObject {
	@private BOOL m_running;
}

@property (readwrite, assign) BOOL running;

// implemented by subclasses
+ (void) load;
- (NSString *) name;
- (void) addObserver: (Rule *) rule;
- (void) removeObserver: (Rule *) rule;
- (void) start;
- (void) stop;

@end
