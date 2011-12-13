//
//  SourcesManager.m
//  ControlPlane
//
//  Created by David Jennes on 18/09/11.
//  Copyright 2011. All rights reserved.
//

#import "CallbackSource.h"
#import "LoopingSource.h"
#import "Rule.h"
#import "Source.h"
#import "SourcesManager.h"
#import "SynthesizeSingleton.h"

@implementation SourcesManager

SYNTHESIZE_SINGLETON_FOR_CLASS(SourcesManager);

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	if (!self) return nil;
	
	m_sources = [NSMutableDictionary new];
	
	return self;
}

#pragma mark - Source types

- (void) registerSourceType: (Class) type {
	ZAssert([type conformsToProtocol: @protocol(SourceProtocol)], @"Unsupported Source type");
	
	// create it
	@synchronized(m_sources) {
		Source *source = [type new];
		[m_sources setObject: source forKey: type];
		LogInfo_Source(@"Registererd source: %@", source.name);
	}
}

- (void) unregisterSourceType: (Class) type {
	ZAssert([m_sources objectForKey: type], @"Unknown source type");
	
	// remove it
	@synchronized(m_sources) {
		[m_sources removeObjectForKey: type];
		LogInfo_Source(@"Unregistererd source: %@", NSStringFromClass(type));
	}
}

- (Source *) getSource: (Class) type {
	@synchronized(m_sources) {
		return [m_sources objectForKey: type];
	}
}

#pragma mark - Rules registration

- (void) registerRule: (Rule *) rule toSource: (Class) type {
	@synchronized(m_sources) {
		// find it
		Source *source = [self getSource: type];
		ZAssert(source, @"Unknown source: %@", NSStringFromClass(type));
		
		// register
		[source addObserver: rule];
	}
}

- (void) unregisterRule: (Rule *) rule fromSource: (Class) type {
	@synchronized(m_sources) {
		// find it
		Source *source = [self getSource: type];
		ZAssert(source, @"Unknown source: %@", NSStringFromClass(type));
		
		// unregister
		[source removeObserver: rule];
	}
}

@end
