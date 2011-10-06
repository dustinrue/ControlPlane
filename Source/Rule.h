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
	BOOL m_match;
	NSNumber *m_enabled;
	NSDictionary *m_data;
}

@property (readwrite, copy) NSDictionary *data;
@property (readwrite, assign) BOOL enabled;
@property (readwrite, assign) BOOL match;

@end
