//
//  Context.m
//  ControlPlane
//
//  Created by David Jennes on 23/09/11.
//  Copyright 2011. All rights reserved.
//

#import "Context.h"
#import "KVOAdditions.h"
#import <Plugins/Actions.h>
#import <Plugins/Rules.h>

@interface Context (Private)

- (void) ruleMatchChangedWithOld: (BOOL) oldMatch andNew: (BOOL) newMatch;
- (void) activated;
- (void) deactivated;
+ (NSString *) stringWithUUID;

@end

@implementation Context

@synthesize actions = m_actions;
@synthesize active = m_active;
@synthesize confidence = m_confidence;
@synthesize name = m_name;
@synthesize rules = m_rules;
@synthesize uuid = m_uuid;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	if (!self) return nil;
	
	m_actions = [NSMutableArray new];
	m_actionsLock = [NSLock new];
	m_rules = [NSMutableArray new];
	self.active = NO;
	self.confidence = 0;
	self.name = nil;
	self.uuid = [Context stringWithUUID];
	
	return self;
}

#pragma mark - Actions

- (void) addAction: (Action *) action {
	@synchronized(m_actionsLock) {
		ZAssert([self.actions containsObject: action], @"Context already owns action");
		[m_actions addObject: action];
	}
}

- (void) removeAction: (Action *) action {
	@synchronized(m_actionsLock) {
		ZAssert(![self.actions containsObject: action], @"Context doesn't own action");
		[m_actions removeObject: action];
	}
}

#pragma mark - Rules

- (void) addRule: (Rule *) rule {
	ZAssert([self.rules containsObject: rule], @"Context already owns rule");
	[m_rules addObject: rule];
	
	// observe if needed
	if (self.active)
		[rule addObserver: self
			   forKeyPath: @"match"
				  options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
				 selector: @selector(ruleMatchChangedWithOld:andNew:)];
}

- (void) removeRule: (Rule *) rule {
	ZAssert(![self.rules containsObject: rule], @"Context doesn't own rule");
	[m_rules removeObject: rule];
	
	// stop observing
	[rule removeObserver: self forKeyPath: @"match"];
}

- (void) ruleMatchChangedWithOld: (BOOL) oldMatch andNew: (BOOL) newMatch {
	if (oldMatch == newMatch)
		return;
	
	// recalculate our confidence level, using (a modified version of) Hooper's Rule
	// namely: Ctot = 1 - ((1 - C1) * (1 - C2) * (1 - C3) * ... )
	
	double product = 1.0;
	for (Rule *rule in self.rules)
		if (rule.match)
			product *= 1.0 - (rule.confidence / 100.0);
	product = (1.0 - product);
	NSUInteger confidence = (NSUInteger) (100 * product);
	
	// store it
	if (self.confidence != confidence)
		self.confidence = confidence;
}

#pragma mark - Activation

- (BOOL) active {
	return m_active;
}

- (void) setActive: (BOOL) active {
	if (!m_active && active)
		[self activated];
	else if (m_active && !active)
		[self deactivated];
	
	m_active = active;
}

- (void) activated {
	@synchronized(m_actionsLock) {
		LogInfo_Context(@"Activated context '%@', executing actions", self.name);
		[ActionsManager.sharedActionsManager executeActions: m_actions when: kWhenEntering];
	}
}

- (void) deactivated {
	@synchronized(m_actionsLock) {
		LogInfo_Context(@"Deactivated context '%@', executing actions", self.name);
		[ActionsManager.sharedActionsManager executeActions: m_actions when: kWhenLeaving];
	}
}

#pragma mark - Helper functions

+ (NSString *) stringWithUUID {
	CFUUIDRef uuidObj = CFUUIDCreate(nil);
	
	// convert to string
	NSString *uuidString = (__bridge_transfer NSString *) CFUUIDCreateString(nil, uuidObj);
	CFRelease(uuidObj);
	
	return uuidString;
}

@end
