//
//  Action.h
//  ControlPlane
//
//  Created by David Jennes on 01/10/11.
//  Copyright 2011. All rights reserved.
//

typedef enum {
	kWhenEntering = 0,
	kWhenLeaving = 1
} eWhen;

@protocol ActionProtocol <NSObject>

- (void) loadData: (id) data;
- (BOOL) execute;
- (NSString *) describeValue: (id) value;

@property (readonly) NSString *name;
@property (readonly) NSString *category;
@property (readonly) NSArray *suggestedValues;

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
@property (readwrite, copy) NSDictionary *data;

@end
