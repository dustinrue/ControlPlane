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
	[super dealloc];
}

- (void) setListenersCount: (unsigned int) listenersCount {
	if (!self.running && listenersCount > 0)
		[self start];
	else if (self.running && listenersCount == 0)
		[self stop];
	
	m_listenersCount = listenersCount;
}

- (NSString *) name {
	return NSStringFromClass(self.class);
}

- (void) addObserver: (Rule *) rule {
	SEL sel = nil;
	
	for (NSString *key in self.observableKeys) {
		sel = NSSelectorFromString([NSString stringWithFormat: @"%@ChangedWithOld:andNew:", key]);
		
		if ([rule respondsToSelector: sel])
			[self addObserver: rule
				   forKeyPath: key
					  options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
					 selector: sel];
	}
}

- (void) removeObserver: (Rule *) rule {
	for (NSString *key in self.observableKeys)
		[self removeObserver: rule forKeyPath: key selector: nil];
}

#pragma mark - Subclass functions

+ (void) load {
	[self doesNotRecognizeSelector: _cmd];
}

- (NSArray *) observableKeys {
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (void) start {
	[self doesNotRecognizeSelector: _cmd];
}

- (void) stop {
	[self doesNotRecognizeSelector: _cmd];
}

@end
