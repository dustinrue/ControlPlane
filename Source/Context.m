//
//  Context.m
//  ControlPlane
//
//  Created by David Jennes on 23/09/11.
//  Copyright 2011. All rights reserved.
//

#import "CAction.h"
#import "Context.h"
#import "Rule.h"

@interface Context (Private)

- (void) activated;
- (void) deactivated;

@end

@implementation Context

@synthesize name = m_name;
@synthesize active = m_active;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
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
	
	for (CAction *action in m_actions)
		;
}

- (void) deactivated {
	DLog(@"Deactivated context '%@', executing actions", self.name);
	
	for (CAction *action in m_actions)
		;
}

+ (NSString *) stringWithUUID {
	CFUUIDRef uuidObj = CFUUIDCreate(nil);
	
	// convert to string
	NSString *uuidString = (NSString *) CFUUIDCreateString(nil, uuidObj);
	CFRelease(uuidObj);
	
	return [uuidString autorelease];
}

@end
