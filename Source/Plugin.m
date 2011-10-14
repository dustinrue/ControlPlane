//
//  Plugin.m
//  ControlPlane
//
//  Created by David Jennes on 05/10/11.
//  Copyright 2011. All rights reserved.
//

#import "Plugin.h"
#import "ActionsManager.h"
#import "RulesManager.h"
#import "SourcesManager.h"
#import "ViewsManager.h"

@implementation Plugin

@synthesize bundle = m_bundle;

+ (BOOL) initPlugin: (NSBundle *) bundle {
	return YES;
}

+ (id<Plugin>) createPlugin: (NSBundle *) bundle {
	Class class = [bundle principalClass];
	id<Plugin> plugin = (id<Plugin>) [[class alloc] initWithBundle: bundle];
	
	return plugin;
}

+ (void) stopPlugin {
}

- (id) initWithBundle: (NSBundle *) bundle {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_bundle = bundle;
	[self registerTypesWithManagers];
    
	return self;
}

- (void) dealloc {
	[self unregisterTypesWithManagers];
}

- (void) registerTypesWithManagers {
	for (Class source in self.sources)
		[SourcesManager.sharedSourcesManager registerSourceType: source];
	for (Class rule in self.rules)
		[RulesManager.sharedRulesManager registerRuleType: rule];
	for (Class action in self.actions)
		[ActionsManager.sharedActionsManager registerActionType: action];
	for (Class view in self.views)
		[ViewsManager.sharedViewsManager registerViewType: view];
}

- (void) unregisterTypesWithManagers {
	for (Class view in self.views)
		[ViewsManager.sharedViewsManager unregisterViewType: view];
	for (Class action in self.actions)
		[ActionsManager.sharedActionsManager unregisterActionType: action];
	for (Class rule in self.rules)
		[RulesManager.sharedRulesManager unregisterRuleType: rule];
	for (Class source in self.sources)
		[SourcesManager.sharedSourcesManager unregisterSourceType: source];
}

- (NSString *) name {
    return [self.bundle.infoDictionary valueForKey: @"CFBundleExecutable"];
}

- (NSString *) identifier {
    return self.bundle.bundleIdentifier;
}

- (NSString *) info {
    return [self.bundle.infoDictionary valueForKey: @"CFBundleGetInfoString"];
}

- (NSUInteger) version {
    return [[self.bundle.infoDictionary valueForKey: @"CFBundleVersion"] unsignedIntValue];
}

- (NSUInteger) apiVersion {
	return 1;
}

- (NSArray *) actions {
	return [NSArray array];
}

- (NSArray *) rules {
	return [NSArray array];
}

- (NSArray *) sources {
	return [NSArray array];
}

- (NSArray *) views {
	return [NSArray array];
}

@end
