//
//  CombinedRule.h
//  ControlPlane
//
//  Created by David Jennes on 10/12/11.
//  Copyright 2011. All rights reserved.
//

#import <Plugins/Rule.h>

typedef enum {
	kRuleAll = 0,
	kRuleAny = 1,
	kRuleNone = 2
} eRuleType;

@interface CombinedRule : Rule<RuleProtocol> {
	NSArray *m_rules;
	eRuleType m_type;
}

@property (readonly, copy) NSArray *rules;
@property (readwrite, assign) eRuleType type;

@end
