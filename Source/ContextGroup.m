//
//  ContextGroup.m
//  ControlPlane
//
//  Created by David Jennes on 23/09/11.
//  Copyright 2011. All rights reserved.
//

#import "Context.h"
#import "ContextGroup.h"
#import "KVOAdditions.h"
#import <Plugins/Actions.h>

@interface ContextGroup (Private)

- (void) confidenceChangedWithOld: oldConfidence andNew: newConfidence;
- (void) activateSuggestion;

@end

@implementation ContextGroup

@synthesize name = m_name;
@synthesize activeContext = m_activeContext;

- (id) initWithName: (NSString *) name {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	if (!self) return nil;
	
	m_contexts = [NSMutableDictionary new];
	m_suggestedContext = nil;
	m_suggestionTimer = nil;
	self.activeContext = nil;
	self.name = name;
	
	return self;
}

#pragma mark - Contexts

- (void) addContext: (Context *) context {
	ZAssert([m_contexts objectForKey: context.name], @"Group already owns context");
	[m_contexts setObject: context forKey: context.name];
	
	[context addObserver: self
			  forKeyPath: @"confidence"
				 options: 0
				selector: @selector(confidenceChangedWithOld:andNew:)];
}

- (void) removeContext: (NSString *) context {
	ZAssert(![m_contexts objectForKey: context], @"Group doesn't own context");
	[m_contexts removeObjectForKey: context];
}

#pragma mark - Context switching

- (void) confidenceChanged {
	Context *suggestion = nil;
	
	// find context with highest confidence
	for (Context *context in m_contexts.allValues)
		if (context.match) {
			suggestion = context;
			break;
		}
	
	// Do we have a new suggestion?
	if (m_suggestedContext != suggestion) {
		[m_suggestionTimer invalidate];
		m_suggestedContext = suggestion;
		
		m_suggestionTimer = [NSTimer scheduledTimerWithTimeInterval: 3.0
															 target: self
														   selector: @selector(activateSuggestion)
														   userInfo: nil
															repeats: NO];
	}
}

- (void) activateSuggestion {
	m_suggestionTimer = nil;
	if (self.activeContext == m_suggestedContext)
		return;
	
	// leave old context
	self.activeContext.active = NO;
	do {
		[NSThread sleepForTimeInterval: 1];
	} while ([ActionsManager.sharedActionsManager executionInProgress]);
	
	// enter new context
	self.activeContext = m_suggestedContext;
	self.activeContext.active = YES;
	do {
		[NSThread sleepForTimeInterval: 1];
	} while ([ActionsManager.sharedActionsManager executionInProgress]);
}

@end
