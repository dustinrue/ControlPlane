//
//  Plugin.m
//  ControlPlane
//
//  Created by David Jennes on 05/10/11.
//  Copyright 2011. All rights reserved.
//

#import "Plugin.h"

@implementation Plugin

@synthesize bundle = m_bundle;

+ (BOOL) initPlugin: (NSBundle *) bundle {
	return YES;
}

+ (id<Plugin>) createPlugin: (NSBundle *) bundle {
	Class class = [bundle principalClass];
	id<Plugin> plugin = (id<Plugin>) [[[class alloc] initWithBundle: bundle] autorelease];
	
	return plugin;
}

+ (void) stopPlugin {
}

- (id) initWithBundle: (NSBundle *) bundle {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_bundle = [bundle retain];
    
	return self;
}

- (void) dealloc {
    [m_bundle release];
    [super dealloc];
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
    return [[self.bundle.infoDictionary valueForKey: @"CFBundleVersion"] intValue];
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

@end
