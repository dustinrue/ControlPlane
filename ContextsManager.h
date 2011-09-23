//
//  ContextsManager.h
//  ControlPlane
//
//  Created by David Jennes on 23/09/11.
//  Copyright 2011. All rights reserved.
//

@class Context;
@class ContextGroup;

@interface ContextsManager : NSObject {
	NSMutableDictionary *m_groups;
}

+ (ContextsManager *) sharedContextsManager;
- (void) createGroup: (NSString *) name;
- (void) removeGroup: (NSString *) name;
- (void) addContext: (Context *) context toGroup: (NSString *) name;
- (void) removeContext: (NSString *) context fromGroup: (NSString *) name;
- (ContextGroup *) getGroup: (NSString *) name;

@end
