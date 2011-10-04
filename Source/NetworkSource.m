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

- (void) checkAddressesThread;
- (void) checkInterfacesThread;

@end

@implementation NetworkSource

registerSourceType(NetworkSource)
@synthesize addresses = m_addresses;
@synthesize interfaces = m_interfaces;
@synthesize interfaceNames = m_interfaceNames;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	self.addresses = [[NSArray new] autorelease];
	self.interfaces = [[NSDictionary new] autorelease];
	self.interfaceNames = [[NSDictionary new] autorelease];
	
	return self;
}

- (void) dealloc {
	[super dealloc];
}

#pragma mark - Required implementation of 'CallbackSource' class

- (NSArray *) observableKeys {
	return [NSArray arrayWithObjects: @"interfaces", @"addresses", nil];
}

- (void) registerCallback {
	NSArray *interfaces = [(NSArray *) SCNetworkInterfaceCopyAll() autorelease];
	NSMutableArray *keys = [[NSMutableArray new] autorelease];
	
	// monitor interfaces
	for (NSUInteger i = 0; i < interfaces.count; ++i) {
		SCNetworkInterfaceRef interface = (SCNetworkInterfaceRef) [interfaces objectAtIndex: i];
		[keys addObject: [NSString stringWithFormat: 
						  @"State:/Network/Interface/%@/Link",
						  SCNetworkInterfaceGetBSDName(interface)]];
	}
	
	// monitor IP changes
	[keys addObject: @"State:/Network/Global/IPv4"];
	
	// register for async. notifications
	SCDynamicStoreContext ctxt = {0, self, NULL, NULL, NULL};
	m_store = SCDynamicStoreCreate(NULL, CFSTR("ControlPlane"), storeChange, &ctxt);
	m_runLoop = SCDynamicStoreCreateRunLoopSource(NULL, m_store, 0);
	
	CFRunLoopAddSource(CFRunLoopGetCurrent(), m_runLoop, kCFRunLoopCommonModes);
	SCDynamicStoreSetNotificationKeys(m_store, (CFArrayRef) keys, NULL);
}

- (void) unregisterCallback {
	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), m_runLoop, kCFRunLoopCommonModes);
	CFRelease(m_runLoop);
	CFRelease(m_store);
	
	self.addresses = [[NSArray new] autorelease];
	self.interfaces = [[NSDictionary new] autorelease];
	self.interfaceNames = [[NSDictionary new] autorelease];
}

- (void) checkData {
	[NSThread detachNewThreadSelector: @selector(checkAddressesThread)
							 toTarget: self
						   withObject: nil];
	[NSThread detachNewThreadSelector: @selector(checkInterfacesThread)
							 toTarget: self
						   withObject: nil];
}

#pragma mark - Threaded data checking

- (void) checkAddressesThread {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	NSThread.currentThread.name = @"NetworkSource-Addresses";
	
	// get all addresses
	NSArray *addresses = NSHost.currentHost.addresses;
	NSMutableArray *result = [[NSMutableArray new] autorelease];
	
	// loop over them
	for (NSString *ip in addresses) {
		ip = ip.lowercaseString;
		
		// filter unusable addresses
		if ([ip hasPrefix:@"127.0.0."] ||	// Localhost IPv4
			[ip isEqualToString:@"::1"] ||	// Localhost IPv6
			[ip hasPrefix:@"ff"] ||			// Multicast IPv6
			[ip hasPrefix:@"169.254."] ||	// Link-local IPv4
			[ip hasPrefix:@"fe80:"])		// Link-local IPv6
			continue;
		
		[result addObject: ip];
	}
	
	// store it
	if (![self.addresses isEqualToArray: result])
		self.addresses = result;
	
	[pool release];
}

- (void) checkInterfacesThread {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	NSThread.currentThread.name = @"NetworkSource-Interfaces";
	
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
	
	[pool release];
}

#pragma mark - Internal callbacks

static void storeChange(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info) {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	NetworkSource *src = (NetworkSource *) info;
	NSArray *keys = (NSArray *) changedKeys;
	NSUInteger todo = keys.count;
	
	// check if addresses changed.
	if ([keys containsObject: @"State:/Network/Global/IPv4"]) {
		[NSThread detachNewThreadSelector: @selector(checkAddressesThread)
								 toTarget: src
							   withObject: nil];
		todo--;
	}
	
	// interfaces might have changed
	if (todo > 0)
		[NSThread detachNewThreadSelector: @selector(checkInterfacesThread)
								 toTarget: src
							   withObject: nil];
	
	[pool release];
}

@end
