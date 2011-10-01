//
//  ActionsManager.m
//  ControlPlane
//
//  Created by David Jennes on 24/09/11.
//  Copyright 2011. All rights reserved.
//

#import "Action.h"
#import "ActionsManager.h"
#import "SynthesizeSingleton.h"

@interface ActionsManager (Private)

- (void) actuallyExecuteAction: (Action *) action;
- (NSDictionary *) filterActions: (NSArray *) actions when: (eWhen) when;

@end

@implementation ActionsManager

SYNTHESIZE_SINGLETON_FOR_CLASS(ActionsManager);
@synthesize actionsInProgress = m_actionsInProgress;

- (id) init {
	ZAssert(!sharedActionsManager, @"This is a singleton, use %@.shared%@", NSStringFromClass(self.class), NSStringFromClass(self.class));
	
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_actionTypes = [NSMutableDictionary new];
	self.actionsInProgress = 0;
	
	return self;
}

- (void) dealloc {
	[m_actionTypes release];
	
	[super dealloc];
}

- (BOOL) executionInProgress {
	return m_actionsInProgress > 0;
}

#pragma mark - Action types

- (void) registerActionType: (Class) type {
	[m_actionTypes setObject: type forKey: NSStringFromClass(type)];
}

- (Action *) createActionOfType: (NSString *) type {
	Class actionType = [m_actionTypes objectForKey: type];
	ZAssert(actionType, @"Unknown action type");
	
	return [[actionType new] autorelease];
}

#pragma mark - Action execution

- (void) executeAction: (Action *) action {
	[NSThread detachNewThreadSelector: @selector(actuallyExecuteAction:)
							 toTarget: self
						   withObject: action];
}

- (void) actuallyExecuteAction: (Action *) action {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	NSThread.currentThread.name = action.name;
	BOOL result = NO;
	
	// perform action
	result = [action execute];
	
	// finish up
	if (!result)
		DLog(@"TODO: notify");
	[pool release];
}

#pragma mark - Action set execution

- (void) executeActions: (NSArray *) actions when: (eWhen) when {
	NSDictionary *filteredActions = [self filterActions: actions when: when];
	
	// when entering, sort ascending, otherwise descending
	NSSortDescriptor* sortOrder = [NSSortDescriptor sortDescriptorWithKey: @"self" ascending: (when == kWhenEntering)];
	
	// execution times index
	NSArray *index = [filteredActions.allKeys sortedArrayUsingDescriptors: [NSArray arrayWithObject: sortOrder]];
	
	NSNumber *elapsed = (index.count > 0 ? [index objectAtIndex: 0] : nil);
	for (NSNumber *time in index) {
		// delay
		[NSThread sleepForTimeInterval: fabs(time.doubleValue - elapsed.doubleValue)];
		elapsed = time;
		
		// execute actions
		for (Action *action in [filteredActions objectForKey: elapsed])
			[self executeAction: action];
	}
}

- (NSDictionary *) filterActions: (NSArray *) actions when: (eWhen) when {
	NSMutableDictionary *filteredActions = [[NSMutableDictionary new] autorelease];
	
	// always have an action-set at time (delay) 0.0!
	NSNumber *begin = [NSNumber numberWithDouble: 0.0];
	if (![filteredActions objectForKey: begin])
		[filteredActions setObject: [[NSMutableArray new] autorelease] forKey: begin];
	
	// sort actions by delay
	for (Action *action in actions)
		if (action.enabled && action.when == when) {
			NSMutableArray *list = [filteredActions objectForKey: action.delay];
			
			// if no list, create and store first
			if (!list) {
				list = [[NSMutableArray new] autorelease];
				[filteredActions setObject: list forKey: action.delay];
			}
			
			// store action
			[list addObject: action];
		}
	
	return filteredActions;
}

@end

