//
//  ContextGroup.m
//  ControlPlane
//
//  Created by David Jennes on 23/09/11.
//  Copyright 2011. All rights reserved.
//

#import "Context.h"
#import "ContextGroup.h"

@implementation ContextGroup

@synthesize name = m_name;
@synthesize activeContext = m_activeContext;

- (id) initWithName: (NSString *) name {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	self.name = name;
	self.activeContext = nil;
	m_suggestedContext = nil;
	m_contexts = [NSMutableDictionary new];
	
	return self;
}


- (void) addContext: (Context *) context {
	[m_contexts setObject: context forKey: context.name];
}

- (void) removeContext: (NSString *) context {
	[m_contexts removeObjectForKey: context];
}

@end
