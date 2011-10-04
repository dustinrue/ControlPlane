//
//  NetworkSource.m
//  ControlPlane
//
//  Created by David Jennes on 04/10/11.
//  Copyright 2011. All rights reserved.
//

#import "NetworkSource.h"
#import <SystemConfiguration/SystemConfiguration.h>

static void storeChange(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info);

@interface NetworkSource (Private)

- (void) checkDataThread;

@end

@implementation NetworkSource

registerSourceType(NetworkSource)
@synthesize addresses = m_addresses;
@synthesize interfaces = m_interfaces;
@synthesize interfaceNames = m_interfaceNames;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	self.interfaces = [[NSDictionary new] autorelease];
	self.interfaceNames = [[NSDictionary new] autorelease];
	
	return self;
}

- (void) dealloc {
	[super dealloc];
}

#pragma mark - Required implementation of 'CallbackSource' class

- (NSArray *) observableKeys {
	return [NSArray arrayWithObject: @"interfaces"];
}

- (void) registerCallback {
	NSArray *interfaces = [(NSArray *) SCNetworkInterfaceCopyAll() autorelease];
	NSMutableArray *monitoredInterfaces = [[NSMutableArray new] autorelease];
	
	// monitored interfaces
	for (NSUInteger i = 0; i < interfaces.count; ++i) {
		SCNetworkInterfaceRef interface = (SCNetworkInterfaceRef) [interfaces objectAtIndex: i];
		[monitoredInterfaces addObject: [NSString stringWithFormat: 
										 @"State:/Network/Interface/%@/Link",
										 SCNetworkInterfaceGetBSDName(interface)]];
	}
	
	// register for async. notifications
	SCDynamicStoreContext ctxt = {0, self, NULL, NULL, NULL};
	m_store = SCDynamicStoreCreate(NULL, CFSTR("ControlPlane"), storeChange, &ctxt);
	m_runLoop = SCDynamicStoreCreateRunLoopSource(NULL, m_store, 0);
	
	CFRunLoopAddSource(CFRunLoopGetCurrent(), m_runLoop, kCFRunLoopCommonModes);
	SCDynamicStoreSetNotificationKeys(m_store, (CFArrayRef) monitoredInterfaces, NULL);
}

- (void) unregisterCallback {
	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), m_runLoop, kCFRunLoopCommonModes);
	CFRelease(m_runLoop);
	CFRelease(m_store);
	
	self.interfaces = [[NSDictionary new] autorelease];
	self.interfaceNames = [[NSDictionary new] autorelease];
}

- (void) checkData {
	[NSThread detachNewThreadSelector: @selector(checkDataThread)
							 toTarget: self
						   withObject: nil];
}

#pragma mark - Threaded checkData

- (void) checkDataThread {
	NSMutableDictionary *result = [[NSMutableDictionary new] autorelease];
	NSMutableDictionary *resultNames = [[NSMutableDictionary new] autorelease];
	
	// get all interfaces and our store
	SCDynamicStoreContext ctxt = {0, self, NULL, NULL, NULL};
	SCDynamicStoreRef store = SCDynamicStoreCreate(NULL, CFSTR("ControlPlane"), NULL, &ctxt);
	NSArray *interfaces = [(NSArray *) SCNetworkInterfaceCopyAll() autorelease];
	
	// loop through available interfaces
	for (NSUInteger i = 0; i < interfaces.count; ++i) {
		SCNetworkInterfaceRef interface = (SCNetworkInterfaceRef) [interfaces objectAtIndex: i];
		
		// get data
		NSString *name = (NSString *) SCNetworkInterfaceGetBSDName(interface);
		NSString *readableName = (NSString *) SCNetworkInterfaceGetLocalizedDisplayName(interface);
		NSString *key = [NSString stringWithFormat: @"State:/Network/Interface/%@/Link", name];
		NSDictionary *current = SCDynamicStoreCopyValue(store, (CFStringRef) key);
		
		// process it
		if (!current)
			continue;
		[result setObject: [current objectForKey: @"Active"] forKey: name];
		[resultNames setObject: readableName forKey: name];
		CFRelease(current);
	}
	
	// store it
	if (![self.interfaces isEqualToDictionary: result]) {
		self.interfaceNames = resultNames;
		self.interfaces = result;
	}
}

#pragma mark - Internal callbacks

static void storeChange(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info) {
	NetworkSource *src = (NetworkSource *) info;
	
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	[src checkData];
	[pool release];
}

@end
