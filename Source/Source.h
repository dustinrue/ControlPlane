//
//  Source.h
//  ControlPlane
//
//  Created by David Jennes on 18/09/11.
//  Copyright 2011. All rights reserved.
//

@class Rule;

@protocol SourceProtocol <NSObject>

- (NSArray *) observableKeys;
- (void) start;
- (void) stop;

@end

@interface Source : NSObject {
@private
	BOOL m_running;
	NSNumber *m_listenersCount;
}

@property (readwrite, assign) BOOL running;
@property (readonly) NSUInteger listenersCount;
@property (readonly) NSString *name;

- (void) addObserver: (Rule *) rule;
- (void) removeObserver: (Rule *) rule;

@end
