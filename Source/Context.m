//
//  Context.m
//  ControlPlane
//
//  Created by David Jennes on 23/09/11.
//  Copyright 2011. All rights reserved.
//

#import "Context.h"
#import <Plugins/Actions.h>
#import <Plugins/Rules.h>

@interface Context (Private)

- (void) activated;
- (void) deactivated;
+ (NSString *) stringWithUUID;

@end

@implementation Context

@synthesize active = m_active;
@synthesize name = m_name;
@synthesize uuid = m_uuid;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	self.uuid = [Context stringWithUUID];
	self.name = nil;
	self.active = NO;
	m_rules = [NSMutableArray new];
	m_actions = [NSMutableArray new];
	
	return self;
}

- (void) dealloc {
	[m_rules release];
	[m_actions release];
	
	[super dealloc];
}

- (void) setActive: (BOOL) active {
	if (!m_active && active)
		[self activated];
	else if (m_active && !active)
		[self deactivated];
	
	m_active = active;
}

- (void) activated {
	DLog(@"Activated context '%@', executing actions", self.name);
	[ActionsManager.sharedActionsManager executeActions: m_actions when: kWhenEntering];
}

- (void) deactivated {
	DLog(@"Deactivated context '%@', executing actions", self.name);
	[ActionsManager.sharedActionsManager executeActions: m_actions when: kWhenLeaving];
}

+ (NSString *) stringWithUUID {
	CFUUIDRef uuidObj = CFUUIDCreate(nil);
	
	// convert to string
	NSString *uuidString = (NSString *) CFUUIDCreateString(nil, uuidObj);
	CFRelease(uuidObj);
	
	return [uuidString autorelease];
}

@end
