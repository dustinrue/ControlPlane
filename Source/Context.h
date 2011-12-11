//
//  Context.h
//  ControlPlane
//
//  Created by David Jennes on 23/09/11.
//  Copyright 2011. All rights reserved.
//

@class Action;
@class Rule;

@interface Context : NSObject {
	BOOL m_active;
	BOOL m_match;
	NSString *m_name;
	NSString *m_uuid;
	NSMutableArray *m_actions;
	NSMutableArray *m_rules;
	
	NSLock *m_actionsLock;
}

- (void) addAction: (Action *) action;
- (void) addRule: (Rule *) rule;
- (void) removeAction: (Action *) action;
- (void) removeRule: (Rule *) rule;

@property (readwrite, assign) BOOL active;
@property (readwrite, assign) BOOL match;
@property (readwrite, copy) NSString *name;
@property (readwrite, copy) NSString *uuid;
@property (readonly) NSArray *actions;
@property (readonly) NSArray *rules;

@end
