//
//  ViewsManager.m
//  ControlPlane
//
//  Created by David Jennes on 11/10/11.
//  Copyright 2011. All rights reserved.
//

#import "Action.h"
#import "ActionView.h"
#import "Rule.h"
#import "RuleView.h"
#import "View.h"
#import "ViewsManager.h"
#import "SynthesizeSingleton.h"

@implementation ViewsManager

SYNTHESIZE_SINGLETON_FOR_CLASS(ViewsManager);

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	if (!self) return nil;
	
	m_viewTypes = [NSMutableDictionary new];
	m_viewsAssociation = [NSMutableDictionary new];
	
	return self;
}

#pragma mark - View types

- (void) registerViewType: (Class) type {
	ZAssert([type conformsToProtocol: @protocol(ViewProtocol)], @"Unsupported View type");
	
	LOG_View(0, @"Registererd type: %@", NSStringFromClass(type));
	[m_viewTypes setObject: type forKey: NSStringFromClass(type)];
}

- (void) unregisterViewType: (Class) type {
	[m_viewTypes removeObjectForKey: NSStringFromClass(type)];
	LOG_View(0, @"Registererd type: %@", NSStringFromClass(type));
}

- (View *) viewObject: (id) object {
	Class type = nil;
	
	if ([object respondsToSelector: @selector(customView)])
		type = [object customView];
	else if ([object isKindOfClass: Action.class])
		type = ActionView.class;
	else if ([object isKindOfClass: Rule.class])
		type = RuleView.class;
	else
		ALog(@"Couldn't find a correct view type for object %@.", object);
	
	return [type new];
}

@end
