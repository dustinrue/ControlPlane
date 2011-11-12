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
@property (readonly) NSString *helpText;

@optional
@property (readonly) Class customView;

@end

@interface Rule : NSObject {
@private
	NSUInteger m_confidence;
	BOOL m_enabled;
	NSDictionary *m_data;
	BOOL m_match;
	BOOL m_negation;
	
	NSLock *m_enabledLock;
	NSRecursiveLock *m_matchLock;
}

@property (readwrite, assign) NSUInteger confidence;
@property (readwrite, copy) NSDictionary *data;
@property (readwrite, assign) BOOL enabled;
@property (readwrite, assign) BOOL match;
@property (readwrite, assign) BOOL negation;

@end
