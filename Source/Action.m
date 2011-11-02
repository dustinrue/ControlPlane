//
//  Action.m
//  ControlPlane
//
//  Created by David Jennes on 01/10/11.
//  Copyright 2011. All rights reserved.
//

#import "Action.h"

@implementation Action

@synthesize enabled = m_enabled;
@synthesize delay = m_delay;
@synthesize when = m_when;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	if (!self) return nil;
	
	m_data = [NSDictionary new];
	self.enabled = NO;
	self.delay = 0.0;
	self.when = kWhenEntering;
	
	return self;
}

- (NSDictionary *) data {
	return m_data;
}

- (void) setData: (NSDictionary *) data {
	@synchronized(m_data) {
		// shortly disable (and re-enable) the action while setting it's data
		
		if (m_data != data) {
			self.enabled = NO;
			m_data = [data copy];
			
			// action info
			self.delay = [[m_data objectForKey: @"delay"] doubleValue];
			self.when = [[m_data objectForKey: @"when"] unsignedIntValue];
			BOOL enabled = [[m_data objectForKey: @"enabled"] boolValue];
			
			// load value data
			id value = [m_data objectForKey: @"value"];
			ZAssert(value, @"Data contains no 'value' key");
			[(id<ActionProtocol>) self loadData: value];
			
			self.enabled = enabled;
		}
	}
}

@end
