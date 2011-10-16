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
	
	m_sources = [NSMutableDictionary new];
	
	return self;
}

#pragma mark - Source types

- (void) registerSourceType: (Class) type {
	ZAssert([type conformsToProtocol: @protocol(SourceProtocol)], @"Unsupported Source type");
	
	// create it
	@synchronized(m_sources) {
		Source *source = [type new];
		[m_sources setObject: source forKey: source.name];
		DLog(@"Registererd source: %@", source.name);
	}
}

- (void) unregisterSourceType: (Class) type {
	NSString *name = NSStringFromClass(type);
	
	// Delete source if created
	@synchronized(m_sources) {
		Source *source = [m_sources objectForKey: name];
		ZAssert(source, @"Unknown source type");
		
		[m_sources removeObjectForKey: name];
		DLog(@"Unregistererd source: %@", name);
	}
}

- (Source *) getSource: (NSString *) name {
	@synchronized(m_sources) {
		return [m_sources objectForKey: name];
	}
}

#pragma mark - Rules registration

- (Source *) registerRule: (Rule *) rule toSource: (NSString *) name {
	@synchronized(m_sources) {
		// find it
		Source *source = [self getSource: name];
		ZAssert(source, @"Unknown source: %@", name);
		
		// register
		[source addObserver: rule];
		return source;
	}
}

- (void) unregisterRule: (Rule *) rule fromSource: (NSString *) name {
	@synchronized(m_sources) {
		// find it
		Source *source = [self getSource: name];
		ZAssert(source, @"Unknown source: %@", name);
		
		// unregister
		[source removeObserver: rule];
	}
}

@end
