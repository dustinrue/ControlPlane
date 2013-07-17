//
//  WiFiEvidenceSource2.m
//  ControlPlane
//
//  Created by Dustin Rue on 7/10/11.
//  Copyright 2011 Dustin Rue. All rights reserved.
//
//  Bug fixes and improvements by Vladimir Beloborodov (VladimirTechMan) in Jul 2013.
//

#import <CoreWLAN/CoreWLAN.h>
#import "CoreWLANEvidenceSource.h"
#import "NSMutableArray+Merge.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import "DSLogger.h"

#pragma mark C callbacks

static void linkDataChanged(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info) {
    [(WiFiEvidenceSourceCoreWLAN *) info getInterfaceStateInfo];
}

@interface WiFiEvidenceSourceCoreWLAN () {
    NSLock *lock;
	NSMutableArray *apList;

    // For SystemConfiguration asynchronous notifications
    CFRunLoopSourceRef runLoop;
    SCDynamicStoreRef store;
}

@property(atomic, readwrite, retain) CWInterface *currentInterface;
@property(strong) NSDictionary *interfaceData;
@property BOOL linkActive;
@property(strong) NSString *interfaceBSDName;
@property(strong) NSTimer *loopTimer;

@end

@implementation WiFiEvidenceSourceCoreWLAN

- (id)init {
    self = [super init];
    if (!self) {
		return nil;
    }
    
    lock = [[NSLock alloc] init];
	apList = [[NSMutableArray alloc] init];
	
    return self;
}

- (void)dealloc {
    [self doStop];
    
    [_currentInterface release];
    [lock release];
	[apList release];

    [super dealloc];
}

- (NSString *)description {
    return NSLocalizedString(@"Create rules based on what WiFi networks are available or connected to.", @"");
}

- (bool)isWirelessAvailable {
    return (self.currentInterface && [self.currentInterface powerOn]);
}

- (void)doUpdate:(NSTimer *)timer {
#ifdef DEBUG_MODE
    DSLog(@"timer fired");
#endif
    [self doUpdate];
}

- (void)doUpdate {
    // first see if Wi-Fi is even turned on
    if (![self isWirelessAvailable]) {
        [self clearCollectedData];
        DSLog(@"WiFi disabled, no scan done");
        return;
    }

    // check to see if the interface is busy, lets not check anything if it is
    if ([[self.interfaceData valueForKey:@"Busy"] boolValue]) {
        DSLog(@"WiFi is busy, not updating");
        return;
    }

	NSArray *allAps = nil;
    
    // check to see if the interface is active
    if (!self.linkActive || [[NSUserDefaults standardUserDefaults] boolForKey:@"WiFiAlwaysScans"]) {
        DSLog(@"WiFi link is inactive, doing full scan");
        allAps = [self scanForNetworks];
    } else {
        NSString *ssid = self.currentInterface.ssid, *bssid = self.currentInterface.bssid;
        if ((ssid == nil) || (bssid == nil)) {
            DSLog(@"WiFi interface is active, but is not participating in a network yet (or network SSID is bad)");
            return;
        }
        
        DSLog(@"WiFi link is active, grabbing connection info");
        allAps = @[ @{ @"WiFi SSID": ssid, @"WiFi BSSID": bssid } ];
    }

    [self toggleUpdateLoop:nil];

	[lock lock];

    BOOL isApListChanged = [apList mergeWith:allAps];
	[self setDataCollected:[apList count] > 0];
#ifdef DEBUG_MODE
	//DSLog(@"%@ >> %@", [self class], apList);
#endif

	[lock unlock];

    if (isApListChanged) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"evidenceSourceDataDidChange" object:nil];
    }
}

- (NSMutableArray *)scanForNetworks {
    NSMutableArray *allAps = [NSMutableArray array];

    NSError *err = nil;
    NSSet *foundNetworks = [self.currentInterface scanForNetworksWithSSID:nil error:&err];
    if (err) {
        DSLog(@"Error: %@", err);
        return allAps;
    }

    NSSortDescriptor *sortBySsid = [NSSortDescriptor sortDescriptorWithKey:@"ssid"
                                                                 ascending:YES
                                                                  selector:@selector(caseInsensitiveCompare:)];
    NSArray *scanResults = [foundNetworks sortedArrayUsingDescriptors:@[ sortBySsid ]];
    
    for (CWNetwork *currentNetwork in scanResults) {
        NSString *ssid = [currentNetwork ssid], *bssid = [currentNetwork bssid];
        if ((ssid != nil) && (bssid != nil)) {
            [allAps addObject:@{ @"WiFi SSID": ssid, @"WiFi BSSID": bssid }];
#ifdef DEBUG_MODE
            DSLog(@"found ssid %@ with bssid %@ and RSSI %ld", ssid, bssid, [currentNetwork rssiValue]);
#endif
        }
    }
    
    return allAps;
}

- (void)clearCollectedData {
	[lock lock];
	[apList removeAllObjects];
	[self setDataCollected:NO];
	[lock unlock];
}

- (NSString *)name {
	return @"WiFi";
}

- (NSArray *)typesOfRulesMatched {
	return @[ @"WiFi BSSID", @"WiFi SSID" ];
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule {
	BOOL match = NO;
	NSString *key = rule[@"type"];
	NSString *param = rule[@"parameter"];

	//[lock lock];
    NSArray *tmp = [apList copy];
	for (NSDictionary *dict in tmp) {
		NSString *x = dict[key];
#ifdef DEBUG_MODE
        DSLog(@"checking to see if %@ matches", x);
#endif
		if ([param isEqualToString:x]) {
			match = YES;
			break;
		}
    }
	//[lock unlock];

    [tmp release];
	return match;
}

- (NSString *)getSuggestionLeadText:(NSString *)type {
	if ([type isEqualToString:@"WiFi BSSID"]) {
		return NSLocalizedString(@"A WiFi access point with a BSSID of", @"In rule-adding dialog");
    }

    return NSLocalizedString(@"A WiFi access point with an SSID of", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions {
	NSMutableArray *arr = [NSMutableArray arrayWithCapacity:(2 * [apList count])];

	[lock lock];

    for (NSDictionary *dict in apList) {
		NSString *mac = dict[@"WiFi BSSID"], *ssid = dict[@"WiFi SSID"];
		[arr addObject: @{  @"type": @"WiFi BSSID",
                            @"parameter": mac,
                            @"description": [NSString stringWithFormat:@"%@ (%@)", mac, ssid] }];
		[arr addObject: @{  @"type": @"WiFi SSID",
                            @"parameter": ssid,
                            @"description": ssid }];
    }
    
	[lock unlock];
    
	return arr;
}

- (NSString *)friendlyName {
    return NSLocalizedString(@"Nearby WiFi Network", @"");
}

- (void)startUpdateLoop {
    if (self.loopTimer) {
        return;
    }

    self.loopTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval) 10
                                                 target:self
                                               selector:@selector(doUpdate:)
                                               userInfo:nil
                                                repeats:YES];
}

- (void)stopUpdateLoop {
    [self.loopTimer invalidate];
    self.loopTimer = nil;
}

- (void)toggleUpdateLoop:(NSNotification *)notification {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"WiFiAlwaysScans"] || !self.linkActive) {
        [self startUpdateLoop];
    }
    else {
        [self stopUpdateLoop];
    }
}

- (void)start {
    if (running) {
        return;
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(toggleUpdateLoop:)
												 name:NSUserDefaultsDidChangeNotification
											   object:nil];

    // attempt to get the current 
    if (![self getWiFiInterface]) {
        [self doStop];
        return;
    }
    
    if (![self registerForAsyncNotifications]) {
        [self doStop];
        return;
    }
    
    [self getInterfaceStateInfo];
    
    [self doUpdate];
    
    [self toggleUpdateLoop:nil];

    running = YES;
}

- (void)stop {
    if (running) {
        [self doStop];
    }
}

- (void)doStop {
    [self stopUpdateLoop];
    [self clearCollectedData];

    if (runLoop) {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoop, kCFRunLoopCommonModes);
        CFRelease(runLoop);
        runLoop = NULL;
    }

    if (store) {
        CFRelease(store);
        store = NULL;
    }

    running = NO;
}

- (BOOL) getWiFiInterface {
    NSArray *supportedInterfaces = [[CWInterface interfaceNames] allObjects];
    
    // get a list of supported Wi-Fi interfaces.  It is unlikely, but still possible,
    // for there to be more than one interface, yet this assumes there is just one
    
    if ([supportedInterfaces count] == 0) {
        DSLog(NSLocalizedString(@"This Mac doesn't appear to have WiFi or your WiFi card has failed",@"The Mac does not have a Wifi/AirPort card or it has failed"));
        self.currentInterface = nil;
        return NO;
    }

    self.currentInterface = [CWInterface interfaceWithName:supportedInterfaces[0]];
    self.interfaceBSDName = [self.currentInterface interfaceName];

#ifdef DEBUG_MODE
    DSLog(@"currentInterface %@\nBSD name %@", self.currentInterface, self.interfaceBSDName);
#endif
    
    return YES;
}

- (BOOL)registerForAsyncNotifications {
	SCDynamicStoreContext ctxt = {0, self, NULL, NULL, NULL}; // {version, info, retain, release, copyDescription}
	store = SCDynamicStoreCreate(NULL, CFSTR("ControlPlane"), linkDataChanged, &ctxt);
    if (!store) {
        return NO;
    }

	runLoop = SCDynamicStoreCreateRunLoopSource(NULL, store, 0);
    if (!runLoop) {
        return NO;
    }

	CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoop, kCFRunLoopCommonModes);

	NSArray *keys = @[ [NSString stringWithFormat:@"State:/Network/Interface/%@/AirPort", self.interfaceBSDName],
                       [NSString stringWithFormat:@"State:/Network/Interface/%@/Link", self.interfaceBSDName] ];
	return SCDynamicStoreSetNotificationKeys(store, (CFArrayRef) keys, NULL);
}

/*
- (void) dumpData {
    BOOL isActive = [[self.interfaceData valueForKey:@"Busy"] boolValue];
    DSLog(@"interface data %@", self.interfaceData);
    DSLog(@"interface is %@", (isActive) ? @"busy":@"not busy");
    DSLog(@"interface is %@", (self.linkActive) ? @"active":@"inactive");
}
*/

- (void)getInterfaceStateInfo {
    NSDictionary *currentData = nil;
    
    currentData = SCDynamicStoreCopyValue(store, (CFStringRef)[NSString stringWithFormat:@"State:/Network/Interface/%@/Link", self.interfaceBSDName]);
    [self setLinkActive:[[currentData valueForKey:@"Active"] boolValue]];
    [currentData release];
    
    currentData = SCDynamicStoreCopyValue(store, (CFStringRef)[NSString stringWithFormat:@"State:/Network/Interface/%@/AirPort", self.interfaceBSDName]);
    [self setInterfaceData:currentData];
    [currentData release];
    
    //[self dumpData];
    [self doUpdate];
}

@end
