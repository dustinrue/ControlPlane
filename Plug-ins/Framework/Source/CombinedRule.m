//
//  CombinedRule.m
//  ControlPlane
//
//  Created by David Jennes on 10/12/11.
//  Copyright 2011. All rights reserved.
//

#import "CombinedRule.h"
#import "KVOAdditions.h"
#import "RulesManager.h"

@interface CombinedRule (Private)

- (BOOL) calculateMatch;
- (void) ruleMatchChangedWithOld: (BOOL) oldMatch andNew: (BOOL) newMatch;

@end

@implementation CombinedRule

@synthesize rules = m_rules;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	if (!self) return nil;
	
	m_rules = [NSArray new];
	m_type = kRuleAny;
	
	return self;
}

- (eRuleType) type {
	return m_type;
}

- (void) setType: (eRuleType) type {
	@synchronized(m_matchLock) {
		if (m_type == type)
			return;
		
		m_type = type;
		
		// recalculate the match flag
		BOOL match = [self calculateMatch];
		if (self.match != match)
			self.match = match;
	}
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"Combined Rule", @"Rule type");
}

- (NSString *) category {
	return NSLocalizedString(@"Internal", @"Rule category");
}

- (NSString *) helpText {
	return NSLocalizedString(@"of the following are true", @"CombinedRule");
}

- (void) beingEnabled {
	for (Rule *rule in self.rules)
		[rule addObserver: self
			   forKeyPath: @"match"
				  options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
				 selector: @selector(ruleMatchChangedWithOld:andNew:)];
}

- (void) beingDisabled {
	for (Rule *rule in self.rules)
		[rule removeObserver: self forKeyPath: @"match"];
}

- (void) loadData: (id) data {
	NSMutableArray *rules = [NSMutableArray new];
	
	// create rules
	for (NSDictionary *ruleData in [data objectForKey: @"rules"]) {
		Rule *rule = [RulesManager.sharedRulesManager createRuleOfType: [ruleData objectForKey: @"type"]];
		
		[(id<RuleProtocol>) rule loadData: [ruleData objectForKey: @"data"]];
		[rules addObject: rule];
	}
	
	m_rules = rules;
	self.type = [[data objectForKey: @"type"] unsignedIntValue];
}

- (NSString *) describeValue: (id) value {
	NSString *result = nil;
	
	switch ([value unsignedIntValue]) {
		case kRuleAll:
			result = NSLocalizedString(@"All", @"CombinedRule value description");
			break;
		case kRuleAny:
			result = NSLocalizedString(@"Any", @"CombinedRule value description");
			break;
		case kRuleNone:
			result = NSLocalizedString(@"None", @"CombinedRule value description");
			break;
		default:
			[NSException raise: NSGenericException format: @"Unexpected eRuleType."];
	}
	
	return result;
}

- (NSArray *) suggestedValues {
	return [NSArray arrayWithObjects:
			[NSNumber numberWithInt: kRuleAll],
			[NSNumber numberWithInt: kRuleAny],
			[NSNumber numberWithInt: kRuleNone],
			nil];
}

#pragma mark - Helper methods

- (BOOL) calculateMatch {
	BOOL result = YES;
	
	// go through rules
	for (Rule *rule in self.rules)
		if (self.type == kRuleAll || self.type == kRuleNone)
			result &= rule.match;
		else
			result |= rule.match;
	
	// none is same as !all
	if (self.type == kRuleNone)
		result = !result;
	
	return result;
}

- (void) ruleMatchChangedWithOld: (BOOL) oldMatch andNew: (BOOL) newMatch {
	if (oldMatch == newMatch)
		return;
	
	BOOL match = [self calculateMatch];
	
	// store it
	if (self.match != match)
		self.match = match;
}

@end
