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

- (void) executeAction: (Action *) action;
- (NSDictionary *) filterActions: (NSArray *) actions when: (eWhen) when;

@property (readwrite, assign) NSUInteger actionsInProgress;

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
	ZAssert([type conformsToProtocol: @protocol(ActionProtocol)], @"Unsupported Action type");
	[m_actionTypes setObject: type forKey: NSStringFromClass(type)];
}

- (Action *) createActionOfType: (NSString *) type {
	Class actionType = [m_actionTypes objectForKey: type];
	ZAssert(actionType, @"Unknown action type");
	
	return [[actionType new] autorelease];
}

#pragma mark - Action execution

- (void) executeAction: (Action *) action {
	BOOL result = NO;
	self.actionsInProgress++;
	
	// This is called with detachThread, so create pool and set thread name
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	NSThread.currentThread.name = ((id<ActionProtocol>) action).name;
	
	// perform action
	result = [(id<ActionProtocol>) action execute];
	
	// finish up
	if (!result)
		DLog(@""); // TODO: notify
	self.actionsInProgress--;
	[pool release];
}

#pragma mark - Action set execution

- (void) executeActions: (NSArray *) actions when: (NSUInteger) when {
	NSDictionary *filteredActions = [self filterActions: actions when: (eWhen) when];
	
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
		for (Action *action in [filteredActions objectForKey: elapsed]) {
			[NSThread detachNewThreadSelector: @selector(executeAction:)
									 toTarget: self
								   withObject: action];
		}
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

