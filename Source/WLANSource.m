//
//	WLANSource.m
//	ControlPlane
//
//	Created by David Jennes on 22/09/11.
//	Copyright 2011. All rights reserved.
//

#import "KVOAdditions.h"
#import "Rule.h"
#import "SourcesManager.h"
#import "WLANSource.h"
#import <CoreWLAN/CoreWLAN.h>

@interface WLANSource (Private)

- (NSArray *) scanForNetworks: (CWInterface *) interface;

@end

@implementation WLANSource

@synthesize networks = m_networks;

- (id) init {
	self = [super init];
	if (!self)
		return nil;
	
	self.networks = [[[NSArray alloc] init] autorelease];
	
	return self;
}

#pragma mark - Required implementation of 'Source' class

+ (void) load {
	[[SourcesManager sharedSourcesManager] registerSourceType: self];
}

- (NSString *) name {
	return @"WLAN";
}

- (void) addObserver: (Rule *) rule {
	SEL selector = NSSelectorFromString(@"networksChangedWithOld:andNew:");
	
	[self addObserver: rule
		   forKeyPath: @"networks"
			  options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
			 selector: selector];
}

- (void) removeObserver: (Rule *) rule {
	[self removeObserver: rule forKeyPath: @"networks" selector: nil];
}

- (void) checkData {
	NSArray *supportedInterfaces = [CWInterface supportedInterfaces];
	NSArray *results = nil;

	// get a list of supported Wi-Fi interfaces.  It is highly unlikely, but still possible, for there to
	// be more than one interface, but we'll only use the first one
	CWInterface *interface = [CWInterface interfaceWithName: [supportedInterfaces objectAtIndex: 0]];
	if (!interface.power) {
		DLog(@"Wi-Fi disabled, no scan done");
		return;
	}
	
	// see if we are currently connected to an AP
	NSString *currentSSID = interface.ssid;
	
	// depending on if we're already associated an the AlwaysScan preference,
	// use the current connection info or perform a scan of APs.
	if (currentSSID && ![[NSUserDefaults standardUserDefaults] boolForKey: @"WiFiAlwaysScans"]) {
		DLog(@"Already associated with an AP, using connection info");
		results = [NSArray arrayWithObject: [NSDictionary dictionaryWithObjectsAndKeys:
											 interface.ssid, @"SSID",
											 interface.bssid, @"BSSID", nil]];
	} else
		results = [self scanForNetworks: interface];
	
	// store it
	self.networks = results;
}

#pragma mark - Helper functions

- (NSArray *) scanForNetworks: (CWInterface *) interface {
	NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys: nil];
	NSMutableArray *results = [NSMutableArray array];
	NSMutableArray *scanResults = nil;
	NSError *err = nil;
	
	// scan
	scanResults = [NSMutableArray arrayWithArray: [interface scanForNetworksWithParameters: params error: &err]];
	ZAssert(err, @"error: %@", err);
	
	// sort results
	NSSortDescriptor *desc = [[[NSSortDescriptor alloc] initWithKey: @"ssid"
														  ascending: YES
														   selector: @selector(caseInsensitiveCompare:)] autorelease];
	[scanResults sortUsingDescriptors: [NSArray arrayWithObject: desc]];
	
	// fill results array
	for (CWNetwork *network in scanResults) {
		[results addObject: [NSDictionary dictionaryWithObjectsAndKeys:
							 [network ssid], @"WiFi SSID",
							 [network bssid], @"WiFi BSSID", nil]];
		DLog(@"Found ssid %@ with bssid %@ and RSSI %@", [network ssid], [network bssid], [network rssi]);
	}
	
	return results;
}

@end
