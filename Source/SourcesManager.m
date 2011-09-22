//
//  SourcesManager.m
//  ControlPlane
//
//  Created by David Jennes on 18/09/11.
//  Copyright 2011. All rights reserved.
//

#import "Rule.h"
#import "Source.h"
#import "SourcesManager.h"
#import "SynthesizeSingleton.h"
#import <libkern/OSAtomic.h>

@interface SourcesManager (Private)

- (void) createSources;

@end

@implementation SourcesManager

SYNTHESIZE_SINGLETON_FOR_CLASS(SourcesManager);

- (id) init {
	if (sharedSourcesManager) {
		[NSException raise:NSInternalInconsistencyException
					format:@"[%@ %@] cannot be called; use +[%@ %@] instead"],
					NSStringFromClass([self class]), NSStringFromSelector(_cmd), 
					NSStringFromClass([self class]),
					NSStringFromSelector(@selector(sharedInstance));
		return nil;
	}
	
	self = [super init];
	if (!self)
		return nil;
	
	m_sources = [[NSMutableDictionary alloc] init];
	m_sourceTypes = [[NSMutableArray alloc] init];
	m_sourcesCreated = NO;
	
	return self;
}

- (void) dealloc {
	[m_sources release];
	[m_sourceTypes release];
	
	[super dealloc];
}

#pragma mark - Source types

- (void) registerSourceType: (Class) type {
	[m_sourceTypes addObject: type];
}

- (void) createSources {
	Source *source = nil;
	
	// create an instance of each source type
	for (Class type in m_sourceTypes) {
		source = [[[type alloc] init] autorelease];
		[m_sources setObject: source forKey: source.name];
	}
}

#pragma mark - Rules registration

- (void) registerRule: (Rule *) rule toSource: (NSString *) source {
	if (!m_sourcesCreated)
		[self createSources];
	
	Source *sourceInstance = [m_sources objectForKey: source];
	
	assert(sourceInstance != nil);
	[sourceInstance addObserver: rule];
}

- (void) unRegisterRule: (Rule *) rule fromSource: (NSString *) source {
	if (!m_sourcesCreated)
		[self createSources];
	
	Source *sourceInstance = [m_sources objectForKey: source];
	
	assert(sourceInstance != nil);
	[sourceInstance removeObserver: rule];
}

#pragma mark - Other functions

- (Source *) getSource: (NSString *) name {
	return [m_sources objectForKey: name];
}

@end
