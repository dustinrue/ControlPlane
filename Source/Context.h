//
//  Context.h
//  ControlPlane
//
//  Created by David Jennes on 23/09/11.
//  Copyright 2011. All rights reserved.
//

@interface Context : NSObject {
	BOOL m_active;
	NSString *m_name;
	NSString *m_uuid;
	NSMutableArray *m_actions;
	NSMutableArray *m_rules;
}

@property (readwrite, assign, nonatomic) BOOL active;
@property (readwrite, copy) NSString *name;
@property (readwrite, copy) NSString *uuid;

@end
