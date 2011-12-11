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
#import <objc/message.h>

@interface Source (Private)

@property (readwrite, assign, nonatomic) NSUInteger listenersCount;

@end

@implementation Source

@synthesize running = m_running;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	if (!self) return nil;
	
	m_listenersLock = [NSLock new];
	self.running = NO;
	self.listenersCount = 0;
	
	return self;
}

- (void) dealloc {
	if (self.running)
		[(id<SourceProtocol>) self stop];
}

- (NSUInteger) listenersCount {
	return m_listenersCount;
}

- (void) setListenersCount: (NSUInteger) listenersCount {
	@synchronized(m_listenersLock) {
		if (!self.running && listenersCount > 0)
			[(id<SourceProtocol>) self start];
		else if (self.running && listenersCount == 0)
			[(id<SourceProtocol>) self stop];
		
		m_listenersCount = listenersCount;
	}
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
	
	self.listenersCount++;
}

- (void) removeObserver: (Rule *) rule {
	for (NSString *key in ((id<SourceProtocol>) self).observableKeys)
		[self removeObserver: rule forKeyPath: key selector: nil];
	
	ZAssert(self.listenersCount > 0, @"Source has no listeners!");
	self.listenersCount--;
}

- (void) checkObserver: (Rule *) rule {
	SEL sel = nil;
	
	for (NSString *key in ((id<SourceProtocol>) self).observableKeys) {
		sel = NSSelectorFromString([NSString stringWithFormat: @"%@ChangedWithOld:andNew:", key]);
		
		if ([rule respondsToSelector: sel]) {
			id val = objc_msgSend(self, NSSelectorFromString(key));
			objc_msgSend(rule, sel, val, val);
		}
	}
}

@end
