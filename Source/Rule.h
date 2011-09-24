//
//  Rule.h
//  ControlPlane
//
//  Created by David Jennes on 18/09/11.
//  Copyright 2011. All rights reserved.
//

#import "RulesManager.h"

@interface Rule : NSObject {
@private
	BOOL m_enabled;
	BOOL m_match;
	NSDictionary *m_data;
}

@property (readwrite, copy, nonatomic) NSDictionary *data;
@property (readwrite, assign, nonatomic) BOOL enabled;
@property (readwrite, assign) BOOL match;

// implemented by subclasses
- (NSString *) name;
- (void) beingEnabled;
- (void) beingDisabled;
- (NSArray *) suggestedValues;

@end

// Put this in each source implementation so that it registers with the manager
#define registerRuleType(type) + (void) load { \
	[RulesManager.sharedRulesManager registerRuleType: type.class]; \
}

