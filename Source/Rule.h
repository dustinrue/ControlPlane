//
//  Rule.h
//  ControlPlane
//
//  Created by David Jennes on 18/09/11.
//  Copyright 2011. All rights reserved.
//

@protocol RuleProtocol <NSObject>

- (void) beingEnabled;
- (void) beingDisabled;
- (void) loadData: (id) data;
- (NSString *) describeValue: (id) value;

@property (readonly) NSString *name;
@property (readonly) NSString *category;
@property (readonly) NSArray *suggestedValues;

@optional
@property (readonly) Class customView;

@end

@interface Rule : NSObject {
@private
	NSNumber *m_confidence;
	NSNumber *m_enabled;
	NSDictionary *m_data;
	BOOL m_match;
	NSNumber *m_negation;
}

@property (readwrite, assign) NSNumber *confidence;
@property (readwrite, copy) NSDictionary *data;
@property (readwrite, assign) BOOL enabled;
@property (readwrite, assign) BOOL match;
@property (readwrite, assign) BOOL negation;

@end
