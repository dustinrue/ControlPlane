//
//  RulesManager.m
//  ControlPlane
//
//  Created by David Jennes on 24/09/11.
//  Copyright 2011. All rights reserved.
//

#import "RulesManager.h"
#import "SynthesizeSingleton.h"

@implementation RulesManager

SYNTHESIZE_SINGLETON_FOR_CLASS(RulesManager);

- (id) init {
	ZAssert(!sharedRulesManager, @"This is a singleton, use %@.shared%@", NSStringFromClass(self.class), NSStringFromClass(self.class));
	
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_ruleTypes = [NSMutableDictionary new];
	
	return self;
}

- (void) dealloc {
	[m_ruleTypes release];
	
	[super dealloc];
}

#pragma mark - Rule types

- (void) registerRuleType: (Class) type {
	[m_ruleTypes setObject: type forKey: NSStringFromClass(type)];
}

- (Rule *) createRuleOfType: (NSString *) type {
	Class ruleType = [m_ruleTypes objectForKey: type];
	ZAssert(ruleType, @"Unknown rule type");
	
	return [[ruleType new] autorelease];
}

@end

