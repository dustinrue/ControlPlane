//
//  ActionsManager.h
//  ControlPlane
//
//  Created by David Jennes on 01/10/11.
//  Copyright 2011. All rights reserved.
//

@class Action;

@interface ActionsManager : NSObject {
	NSMutableDictionary *m_actionTypes;
	NSUInteger m_actionsInProgress;
	NSLock *m_executionLock;
}

@property (readonly) BOOL executionInProgress;
@property (readonly) NSUInteger actionsInProgress;

+ (ActionsManager *) sharedActionsManager;
- (void) registerActionType: (Class) type;
- (void) unregisterActionType: (Class) type;
- (Action *) createActionOfType: (NSString *) type;
- (void) executeActions: (NSArray *) actions when: (NSUInteger) when;

@end
