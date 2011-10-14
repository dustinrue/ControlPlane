//
//  ContextGroup.h
//  ControlPlane
//
//  Created by David Jennes on 23/09/11.
//  Copyright 2011. All rights reserved.
//

@class Context;

@interface ContextGroup : NSObject {
	NSString *m_name;
	NSMutableDictionary *m_contexts;
	Context *m_activeContext;
	Context *m_suggestedContext;
	NSTimer *m_suggestionTimer;
}

@property (readwrite, copy) NSString *name;
@property (readwrite, strong) Context *activeContext;

- (id) initWithName: (NSString *) name;
- (void) addContext: (Context *) context;
- (void) removeContext: (NSString *) context;

@end
