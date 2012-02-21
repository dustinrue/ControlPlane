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

@synthesize addresses = m_addresses;
@synthesize interfaces = m_interfaces;
@synthesize interfaceNames = m_interfaceNames;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	self.addresses = [NSArray new];
	self.interfaces = [NSDictionary new];
	self.interfaceNames = [NSDictionary new];
	
	return self;
}

#pragma mark - Required implementation of 'CallbackSource' class

- (NSArray *) observableKeys {
	return [NSArray arrayWithObjects: @"interfaces", @"addresses", nil];
}

- (void) registerCallback {
	NSArray *interfaces = (__bridge_transfer NSArray *) SCNetworkInterfaceCopyAll();
	NSMutableArray *keys = [NSMutableArray new];
	
	// monitor interfaces
	for (NSUInteger i = 0; i < interfaces.count; ++i) {
		SCNetworkInterfaceRef interface = (__bridge SCNetworkInterfaceRef) [interfaces objectAtIndex: i];
		[keys addObject: [NSString stringWithFormat: 
						  @"State:/Network/Interface/%@/Link",
						  SCNetworkInterfaceGetBSDName(interface)]];
	}
	
	// monitor IP changes
	[keys addObject: @"State:/Network/Global/IPv4"];
	
	// register for async. notifications
	SCDynamicStoreContext ctxt = {0, (__bridge void *) self, NULL, NULL, NULL};
	m_store = SCDynamicStoreCreate(NULL, CFSTR("ControlPlane"), storeChange, &ctxt);
	m_runLoop = SCDynamicStoreCreateRunLoopSource(NULL, m_store, 0);
	
	CFRunLoopAddSource(CFRunLoopGetCurrent(), m_runLoop, kCFRunLoopCommonModes);
	SCDynamicStoreSetNotificationKeys(m_store, (__bridge CFArrayRef) keys, NULL);
}

- (void) unregisterCallback {
	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), m_runLoop, kCFRunLoopCommonModes);
	CFRelease(m_runLoop);
	CFRelease(m_store);
	
	self.addresses = [NSArray new];
	self.interfaces = [NSDictionary new];
	self.interfaceNames = [NSDictionary new];
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
	@autoreleasepool {
		NSThread.currentThread.name = @"NetworkSource-Addresses";
		
		// get all addresses
		NSArray *addresses = NSHost.currentHost.addresses;
		NSMutableArray *result = [NSMutableArray new];
		
		// loop over them
		for (__strong NSString *ip in addresses) {
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
	}
}

- (void) checkInterfacesThread {
	@autoreleasepool {
		NSThread.currentThread.name = @"NetworkSource-Interfaces";
		
		NSMutableDictionary *result = [NSMutableDictionary new];
		NSMutableDictionary *resultNames = [NSMutableDictionary new];
		
		// get all interfaces and our store
		SCDynamicStoreContext ctxt = {0, (__bridge void *) self, NULL, NULL, NULL};
		SCDynamicStoreRef store = SCDynamicStoreCreate(NULL, CFSTR("ControlPlane"), NULL, &ctxt);
		NSArray *interfaces = (__bridge_transfer NSArray *) SCNetworkInterfaceCopyAll();
		
		// loop through available interfaces
		for (NSUInteger i = 0; i < interfaces.count; ++i) {
			SCNetworkInterfaceRef interface = (__bridge SCNetworkInterfaceRef) [interfaces objectAtIndex: i];
			
			// get data
			NSString *name = (__bridge NSString *) SCNetworkInterfaceGetBSDName(interface);
			NSString *readableName = (__bridge NSString *) SCNetworkInterfaceGetLocalizedDisplayName(interface);
			NSString *key = [NSString stringWithFormat: @"State:/Network/Interface/%@/Link", name];
			NSDictionary *current = (__bridge_transfer NSDictionary *) (SCDynamicStoreCopyValue(store, (__bridge CFStringRef) key));
			
			// process it
			if (!current)
				continue;
			[result setObject: [current objectForKey: @"Active"] forKey: name];
			[resultNames setObject: readableName forKey: name];
		}
		
		// store it
		if (![self.interfaces isEqualToDictionary: result]) {
			self.interfaceNames = resultNames;
			self.interfaces = result;
		}
	}
}

#pragma mark - Internal callbacks

static void storeChange(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info) {
	@autoreleasepool {
		NetworkSource *src = (__bridge NetworkSource *) info;
		NSArray *keys = (__bridge NSArray *) changedKeys;
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
	}
}

@end
