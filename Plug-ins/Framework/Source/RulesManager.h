//
//  RulesManager.h
//  ControlPlane
//
//  Created by David Jennes on 24/09/11.
//  Copyright 2011. All rights reserved.
//

@class Rule;

@interface RulesManager : NSObject {
	NSMutableDictionary *m_ruleTypes;
}

+ (RulesManager *) sharedRulesManager;
- (void) registerRuleType: (Class) type;
- (void) unregisterRuleType: (Class) type;
- (Rule *) createRuleOfType: (NSString *) type;

@end
