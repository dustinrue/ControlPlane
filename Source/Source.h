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
	@private unsigned int m_listenersCount;
}

@property (readwrite, assign) BOOL running;
@property (readwrite, assign, nonatomic) unsigned int listenersCount;
@property (readonly, copy, nonatomic) NSString *name;

// implemented by subclasses
+ (void) load;
- (void) addObserver: (Rule *) rule;
- (void) removeObserver: (Rule *) rule;
- (void) start;
- (void) stop;

@end
