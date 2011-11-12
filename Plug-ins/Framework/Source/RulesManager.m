//
//  RulesManager.m
//  ControlPlane
//
//  Created by David Jennes on 24/09/11.
//  Copyright 2011. All rights reserved.
//

#import "Rule.h"
#import "RulesManager.h"
#import "SynthesizeSingleton.h"

@implementation RulesManager

SYNTHESIZE_SINGLETON_FOR_CLASS(RulesManager);

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	if (!self) return nil;
	
	m_ruleTypes = [NSMutableDictionary new];
	
	return self;
}

#pragma mark - Rule types

- (void) registerRuleType: (Class) type {
	ZAssert([type conformsToProtocol: @protocol(RuleProtocol)], @"Unsupported Rule type");
	
	LogInfo_Rule(@"Registererd type: %@", NSStringFromClass(type));
	[m_ruleTypes setObject: type forKey: NSStringFromClass(type)];
}

- (void) unregisterRuleType: (Class) type {
	[m_ruleTypes removeObjectForKey: NSStringFromClass(type)];
	LogInfo_Rule(@"Unregistererd type: %@", NSStringFromClass(type));
}

- (Rule *) createRuleOfType: (NSString *) type {
	Class ruleType = [m_ruleTypes objectForKey: type];
	ZAssert(ruleType, @"Unknown rule type");
	
	return [ruleType new];
}

@end

