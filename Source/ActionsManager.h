//
//  ActionsManager.h
//  ControlPlane
//
//  Created by David Jennes on 01/10/11.
//  Copyright 2011. All rights reserved.
//

@class Action;

typedef enum {
	kWhenEntering = 0,
	kWhenLeaving = 1
} eWhen;

@interface ActionsManager : NSObject {
	NSMutableDictionary *m_actionTypes;
	NSUInteger m_actionsInProgress;
}

@property (readonly, assign) BOOL executionInProgress;
@property (readwrite, assign) NSUInteger actionsInProgress;

+ (ActionsManager *) sharedActionsManager;
- (void) registerActionType: (Class) type;
- (Action *) createActionOfType: (NSString *) type;
- (void) executeActions: (NSArray *) actions when: (eWhen) when;

@end
