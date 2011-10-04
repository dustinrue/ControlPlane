//
//  Source.h
//  ControlPlane
//
//  Created by David Jennes on 18/09/11.
//  Copyright 2011. All rights reserved.
//

#import "SourcesManager.h"

@class Rule;

@protocol SourceProtocol <NSObject>

+ (void) load;
- (NSArray *) observableKeys;
- (void) start;
- (void) stop;

@end

@interface Source : NSObject {
@private
	BOOL m_running;
	NSUInteger m_listenersCount;
}

@property (readwrite, assign) BOOL running;
@property (readwrite, assign, nonatomic) NSUInteger listenersCount;
@property (readonly, copy, nonatomic) NSString *name;

- (void) addObserver: (Rule *) rule;
- (void) removeObserver: (Rule *) rule;

@end

// Put this in each source implementation so that it registers with the manager
#define registerSourceType(type) + (void) load { \
	NSAutoreleasePool *pool = [NSAutoreleasePool new]; \
	[SourcesManager.sharedSourcesManager registerSourceType: type.class]; \
	[pool release]; \
}
