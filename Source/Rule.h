//
//  Rule.h
//  ControlPlane
//
//  Created by David Jennes on 18/09/11.
//  Copyright 2011. All rights reserved.
//

#import "RulesManager.h"

@protocol RuleProtocol <NSObject>

- (void) beingEnabled;
- (void) beingDisabled;
- (void) loadData: (id) data;
- (NSString *) describeValue: (id) value;

@property (readonly) NSString *name;
@property (readonly) NSString *category;
@property (readonly) NSArray *suggestedValues;

@end

@interface Rule : NSObject {
@private
	BOOL m_enabled;
	BOOL m_match;
	NSDictionary *m_data;
}

@property (readwrite, copy, nonatomic) NSDictionary *data;
@property (readwrite, assign, nonatomic) BOOL enabled;
@property (readwrite, assign) BOOL match;

@end
