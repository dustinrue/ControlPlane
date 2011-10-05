//
//  Source.m
//  ControlPlane
//
//  Created by David Jennes on 18/09/11.
//  Copyright 2011. All rights reserved.
//

#import "KVOAdditions.h"
#import "Rule.h"
#import "Source.h"

@implementation Source

@synthesize running = m_running;
@synthesize listenersCount = m_listenersCount;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	self.running = NO;
	self.listenersCount = 0;
	
	return self;
}

- (void) dealloc {
	if (self.running)
		[(id<SourceProtocol>) self stop];
	
	[super dealloc];
}

- (void) setListenersCount: (NSUInteger) listenersCount {
	if (!self.running && listenersCount > 0)
		[(id<SourceProtocol>) self start];
	else if (self.running && listenersCount == 0)
		[(id<SourceProtocol>) self stop];
	
	m_listenersCount = listenersCount;
}

- (NSString *) name {
	return NSStringFromClass(self.class);
}

- (void) addObserver: (Rule *) rule {
	SEL sel = nil;
	
	for (NSString *key in ((id<SourceProtocol>) self).observableKeys) {
		sel = NSSelectorFromString([NSString stringWithFormat: @"%@ChangedWithOld:andNew:", key]);
		
		if ([rule respondsToSelector: sel])
			[self addObserver: rule
				   forKeyPath: key
					  options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
					 selector: sel];
	}
}

- (void) removeObserver: (Rule *) rule {
	for (NSString *key in ((id<SourceProtocol>) self).observableKeys)
		[self removeObserver: rule forKeyPath: key selector: nil];
}

@end
