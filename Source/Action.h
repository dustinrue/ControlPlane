//
//  Action.h
//  ControlPlane
//
//  Created by David Jennes on 01/10/11.
//  Copyright 2011. All rights reserved.
//

#import "ActionsManager.h"

@protocol ActionProtocol <NSObject>

- (NSString *) name;
- (NSString *) category;
- (void) loadData: (id) data;
- (BOOL) execute;
- (NSString *) describeValue: (id) value;
- (NSArray *) suggestedValues;

@end

@interface Action : NSObject {
@private
	BOOL m_enabled;
	NSNumber *m_delay;
	eWhen m_when;
	NSDictionary *m_data;
}

@property (readwrite, assign) BOOL enabled;
@property (readwrite, assign) NSNumber *delay;
@property (readwrite, assign) eWhen when;
@property (readwrite, copy, nonatomic) NSDictionary *data;

@end

// Put this in each source implementation so that it registers with the manager
#define registerActionType(type) + (void) load { \
	NSAutoreleasePool *pool = [NSAutoreleasePool new]; \
	[RulesManager.sharedRulesManager registerActionType: type.class]; \
	[pool release]; \
}
