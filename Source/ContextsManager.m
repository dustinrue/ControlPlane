//
//  ContextsManager.m
//  ControlPlane
//
//  Created by David Jennes on 23/09/11.
//  Copyright 2011. All rights reserved.
//

#import "ContextGroup.h"
#import "ContextsManager.h"
#import "SynthesizeSingleton.h"

@implementation ContextsManager

SYNTHESIZE_SINGLETON_FOR_CLASS(ContextsManager);

- (id) init {
	ZAssert(!sharedContextsManager, @"This is a singleton, use %@.shared%@", NSStringFromClass(self.class), NSStringFromClass(self.class));
	
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_groups = [NSMutableDictionary new];
	
	return self;
}


#pragma mark - Context management

- (void) createGroup: (NSString *) name {
	ContextGroup *group = [[ContextGroup alloc] initWithName: name];
	
	[m_groups setObject: group forKey: name];
}

- (void) removeGroup: (NSString *) name {
	[m_groups removeObjectForKey: name];
}

- (void) addContext: (Context *) context toGroup: (NSString *) name {
	ContextGroup *group = [self getGroup: name];
	ZAssert(group, @"Unknown context group %@", name);
	
	[group addContext: context];
}

- (void) removeContext: (NSString *) context fromGroup: (NSString *) name {
	ContextGroup *group = [self getGroup: name];
	ZAssert(group, @"Unknown context group %@", name);
	
	[group removeContext: context];
}

- (ContextGroup *) getGroup: (NSString *) name {
	return [m_groups objectForKey: name];
}

@end
