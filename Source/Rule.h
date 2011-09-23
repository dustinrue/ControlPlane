//
//  Rule.h
//  ControlPlane
//
//  Created by David Jennes on 18/09/11.
//  Copyright 2011. All rights reserved.
//

@interface Rule : NSObject {
	BOOL m_enabled;
	BOOL m_match;
}

// implemented by subclasses
- (void) beingEnabled;
- (void) beingDisabled;

@property (readwrite, assign, nonatomic) BOOL enabled;
@property (readwrite, assign) BOOL match;

@end
