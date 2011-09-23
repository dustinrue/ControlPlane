//
//  Context.h
//  ControlPlane
//
//  Created by David Jennes on 23/09/11.
//  Copyright 2011. All rights reserved.
//

@interface Context : NSObject {
	NSString *m_name;
	NSMutableArray *m_rules;
	NSMutableArray *m_actions;
	BOOL m_active;
}

@property (readwrite, copy) NSString *name;
@property (readwrite, assign, nonatomic) BOOL active;

@end
