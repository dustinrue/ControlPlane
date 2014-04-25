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
#import <SystemConfiguration/SystemConfiguration.h>
#import "CoreWLANEvidenceSource.h"
#import "DSLogger.h"


static char * const queueIsStopped = "queueIsStopped";


#pragma mark C callbacks

static void linkDataChanged(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info) {
    if (dispatch_get_specific(queueIsStopped) != queueIsStopped) {
        @autoreleasepool {
            [(WiFiEvidenceSourceCoreWLAN *) info getInterfaceStateInfo];
        }
    }
}

@interface WiFiEvidenceSourceCoreWLAN () {
@private
    dispatch_source_t pollingTimer;

    // For SystemConfiguration asynchronous notifications
    SCDynamicStoreRef store;
    dispatch_queue_t serialQueue;
}

@property (atomic, retain, readwrite) NSDictionary *networkSSIDs;
@property (atomic, retain, readwrite) NSSet *networkBSSIDs;

@property (atomic, retain, readwrite) CWInterface *currentInterface;
@property (atomic, retain, readwrite) NSString *interfaceBSDName;
@property (atomic, retain, readwrite) NSDictionary *interfaceData;

@property (atomic) BOOL linkActive;

@end

@implementation WiFiEvidenceSourceCoreWLAN

- (id)init {
    self = [super init];
    if (!self) {
		return nil;
    }
    
    return self;
}

- (void)dealloc {
    [self doStop];

    [_networkSSIDs release];
    [_networkBSSIDs release];
    [_currentInterface release];
    [_interfaceBSDName release];
    [_interfaceData release];

    [super dealloc];
}

+ (BOOL) isEvidenceSourceApplicableToSystem {
    return ([[CWInterface interfaceNames] count] > 0);
}

- (void)start {
    if (running) {
        return;
    }
    
    serialQueue = dispatch_queue_create("com.dustinrue.ControlPlane.CoreWLANEvidenceSource",
                                        DISPATCH_QUEUE_SERIAL);
    if (!serialQueue) {
        [self doStop];
        return;
    }
    
    // attempt to get the current
    if (![self getWiFiInterface]) {
        [self doStop];
        return;
    }
    
    if (![self registerForAsyncNotifications]) {
        [self doStop];
        return;
    }
    
    dispatch_async(serialQueue, ^{
        if (dispatch_get_specific(queueIsStopped) != queueIsStopped) {
            @autoreleasepool {
                [self getInterfaceStateInfo];
            }
        }
    });
    
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(toggleUpdateLoop:)
												 name:NSUserDefaultsDidChangeNotification
											   object:nil];
    
    running = YES;
    self.currentNetworkIsSecure = NO;
}

- (void)stop {
    if (running) {
        [self doStop];
    }
}

- (void)doStop {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSUserDefaultsDidChangeNotification
                                                  object:nil];
    [self stopUpdateLoop:NO];

    if (serialQueue) {
        if (store) {
            dispatch_suspend(serialQueue);
            
            SCDynamicStoreSetDispatchQueue(store, NULL);
            
            dispatch_queue_set_specific(serialQueue, queueIsStopped, queueIsStopped, NULL);
            dispatch_resume(serialQueue);
        }
        
        dispatch_release(serialQueue);
        serialQueue = NULL;
    }
    
    if (store) {
        CFRelease(store);
        store = NULL;
    }

    [self clearCollectedData];

    running = NO;
}

- (NSString *)description {
    return NSLocalizedString(@"Create rules based on what WiFi networks are available or connected to.", @"");
}

- (void)doUpdate {
    CWInterface *currentInterface = self.currentInterface;

    // first see if Wi-Fi is even turned on
    if (!currentInterface.powerOn) {
        [self clearCollectedData];
        DSLog(@"WiFi disabled, no scan done");
        return;
    }
    
    // check to see if the interface is busy, lets not check anything if it is
    if ([[self.interfaceData valueForKey:@"Busy"] boolValue]) {
        DSLog(@"WiFi is busy, not updating");
        return;
    }

    NSDictionary *newNetworkSSIDs = nil;

    // check to see if the interface is active
    if (!self.linkActive || [[NSUserDefaults standardUserDefaults] boolForKey:@"WiFiAlwaysScans"]) {
        DSLog(@"WiFi link is inactive, doing full scan");
        newNetworkSSIDs = [self scanForNetworks];
    } else {
        NSString *ssid = currentInterface.ssid, *bssid = currentInterface.bssid;
        if ((ssid == nil) || (bssid == nil)) {
            [self clearCollectedData];
            DSLog(@"WiFi interface is active, but is not participating in a network yet (or network SSID is bad)");
            return;
        }

        DSLog(@"WiFi link is active, grabbing connection info");
        newNetworkSSIDs = @{ ssid: bssid };
        self.currentNetworkIsSecure = (currentInterface.security == kCWSecurityNone || currentInterface.security == kCWSecurityUnknown) ? NO:YES;
    }

    if (![self.networkSSIDs isEqualToDictionary:newNetworkSSIDs]) {
        self.networkSSIDs = newNetworkSSIDs;
        self.networkBSSIDs = (newNetworkSSIDs) ? ([NSSet setWithArray:[newNetworkSSIDs allValues]]) : (nil);
        [self setDataCollected:[newNetworkSSIDs count] > 0];
        
#ifdef DEBUG_MODE
        DSLog(@"%@ >> %@", [self class], newNetworkSSIDs);
#endif
    }
}

- (NSDictionary *)scanForNetworks {
    NSError *err = nil;
    NSSet *foundNetworks = [self.currentInterface scanForNetworksWithName:nil error:&err];
    if (err) {
        DSLog(@"Error: %@", err);
        return nil;
    }

    NSMutableDictionary *ssids = [NSMutableDictionary dictionaryWithCapacity:([foundNetworks count] + 1)];

    for (CWNetwork *currentNetwork in foundNetworks) {
        NSString *ssid = currentNetwork.ssid, *bssid = currentNetwork.bssid;
        if ((ssid != nil) && (bssid != nil)) {
            ssids[ssid] = bssid;
#ifdef DEBUG_MODE
            DSLog(@"found ssid %@ with bssid %@ and RSSI %ld", ssid, bssid, currentNetwork.rssiValue);
#endif
        }
    }

    CWInterface *currentInterface = self.currentInterface;
    if (self.linkActive) {
        NSString *ssid = currentInterface.ssid, *bssid = currentInterface.bssid;
        if ((ssid != nil) && (bssid != nil)) {
            ssids[ssid] = bssid;
            self.currentNetworkIsSecure = (currentInterface.security == kCWSecurityNone || currentInterface.security == kCWSecurityUnknown) ? NO:YES;
#ifdef DEBUG_MODE
            DSLog(@"found ssid %@ with bssid %@ and RSSI %ld", ssid, bssid, currentInterface.rssiValue);
#endif
        }
    }

    return [NSDictionary dictionaryWithDictionary:ssids];
}

- (void)clearCollectedData {
    self.networkSSIDs  = nil;
    self.networkBSSIDs = nil;
    self.currentNetworkIsSecure = NO;
	[self setDataCollected:NO];
}

- (NSString *)name {
	return @"WiFi";
}

- (NSArray *)typesOfRulesMatched {
	return @[ @"WiFi BSSID", @"WiFi SSID", @"WiFi Security" ];
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule {
	NSString *param = rule[@"parameter"];
    
    if ([rule[@"type"] isEqualToString:@"WiFi BSSID"]) {
        return [self.networkBSSIDs containsObject:param];
    }
    
    if ([rule[@"type"] isEqualToString:@"WiFi Security"]) {
        if (!self.linkActive) {
            return NO;
        }
        BOOL isSecure = self.currentNetworkIsSecure;
        return ([param isEqualToString:@"Secure"]) ? (isSecure) : (!isSecure);
    }
    
    return (self.networkSSIDs[param] != nil);
}

- (NSString *)getSuggestionLeadText:(NSString *)type {
	if ([type isEqualToString:@"WiFi BSSID"]) {
		return NSLocalizedString(@"A WiFi access point with a BSSID of", @"In rule-adding dialog");
    }
    
    if ([type isEqualToString:@"WiFi Security"]) {
        return NSLocalizedString(@"Current WiFi network is:", @"In rule-adding dialog");
    }

    return NSLocalizedString(@"A WiFi access point with an SSID of", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions {
    NSDictionary *networkSSIDs = self.networkSSIDs;
    NSArray *sortedSSIDs = [[networkSSIDs allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];

	NSMutableArray *arr = [NSMutableArray arrayWithCapacity:(2 * [networkSSIDs count])];

    for (NSString *ssid in sortedSSIDs) {
		NSString *mac = networkSSIDs[ssid];
		[arr addObject: @{  @"type": @"WiFi BSSID",
                            @"parameter": mac,
                            @"description": [NSString stringWithFormat:@"%@ (%@)", mac, ssid] }];
		[arr addObject: @{  @"type": @"WiFi SSID",
                            @"parameter": ssid,
                            @"description": ssid }];
    }
    
    [arr addObject: @{  @"type": @"WiFi Security",
                        @"parameter": @"Secure",
                        @"description": @"Secure"}];
    [arr addObject: @{  @"type": @"WiFi Security",
                        @"parameter": @"Not Secure",
                        @"description": @"Not Secure"}];
     

	return arr;
}

- (NSString *)friendlyName {
    return NSLocalizedString(@"Nearby WiFi Network", @"");
}

- (void)pollByTimer {
    if (dispatch_get_specific(queueIsStopped) != queueIsStopped) {
        @autoreleasepool {
#ifdef DEBUG_MODE
            DSLog(@"timer fired");
#endif
            [self doUpdate];
        }
    }
}

- (void)startUpdateLoop:(BOOL)forceUpdate {
    if (pollingTimer) {
        return;
    }

    pollingTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, serialQueue);
    if (!pollingTimer) {
        DSLog(@"Failed to create a timer source");
        return;
    }

    const int64_t interval = (int64_t) (10 * NSEC_PER_SEC);
    const int64_t leeway = (int64_t) (3 * NSEC_PER_SEC);
    dispatch_time_t start = (forceUpdate) ? (DISPATCH_TIME_NOW) : (dispatch_time(DISPATCH_TIME_NOW, interval));
    dispatch_source_set_timer(pollingTimer, start, interval, leeway);
    dispatch_source_set_event_handler(pollingTimer, ^{
        [self pollByTimer];
    });

    dispatch_resume(pollingTimer);
}

- (void)stopUpdateLoop:(BOOL)forceUpdate {
    if (pollingTimer) {
        dispatch_source_cancel(pollingTimer);
        dispatch_release(pollingTimer);
        pollingTimer = NULL;

        if (forceUpdate) {
            dispatch_async(serialQueue, ^{
                [self pollByTimer];
            });
        }
    }
}

- (void)toggleUpdateLoop:(NSNotification *)notification {
    BOOL forceUpdate = (notification != nil);
    if (!self.linkActive || [[NSUserDefaults standardUserDefaults] boolForKey:@"WiFiAlwaysScans"]) {
        [self startUpdateLoop:forceUpdate];
    } else {
        [self stopUpdateLoop:forceUpdate];
    }

}

- (BOOL) getWiFiInterface {
    NSArray *supportedInterfaces = [[CWInterface interfaceNames] allObjects];
    
    // get a list of supported Wi-Fi interfaces.  It is unlikely, but still possible,
    // for there to be more than one interface, yet this assumes there is just one
    
    if ([supportedInterfaces count] == 0) {
        DSLog(NSLocalizedString(@"This Mac doesn't appear to have WiFi or your WiFi card has failed",
                                @"The Mac does not have a Wifi/AirPort card or it has failed"));
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
    if (!SCDynamicStoreSetDispatchQueue(store, serialQueue)) {
        return NO;
    }

	NSArray *keys = @[ [NSString stringWithFormat:@"State:/Network/Interface/%@/AirPort", self.interfaceBSDName],
                       [NSString stringWithFormat:@"State:/Network/Interface/%@/Link", self.interfaceBSDName] ];
	return SCDynamicStoreSetNotificationKeys(store, (CFArrayRef) keys, NULL);
}

#ifdef DEBUG_MODE
- (void) dumpData {
    BOOL isBusy = [[self.interfaceData valueForKey:@"Busy"] boolValue];
    DSLog(@"Wi-Fi interface is %@", (self.linkActive) ? @"active" : @"inactive");
    DSLog(@"Wi-Fi interface is %@", (isBusy) ? @"busy" : @"not busy");
    DSLog(@"Wi-Fi interface data: %@", self.interfaceData);
}
#endif

- (void)getInterfaceStateInfo {
    NSDictionary *currentData = nil;

    currentData = SCDynamicStoreCopyValue(store, (CFStringRef)[NSString stringWithFormat:@"State:/Network/Interface/%@/Link", self.interfaceBSDName]);
    [self setLinkActive:[[currentData valueForKey:@"Active"] boolValue]];
    [currentData release];

    currentData = SCDynamicStoreCopyValue(store, (CFStringRef)[NSString stringWithFormat:@"State:/Network/Interface/%@/AirPort", self.interfaceBSDName]);
    [self setInterfaceData:currentData];
    [currentData release];

#ifdef DEBUG_MODE
    [self dumpData];
#endif

    [self doUpdate];

    dispatch_async(dispatch_get_main_queue(), ^{ // start/stop timers on the main loop to ensure synchronous changes
        [self toggleUpdateLoop:nil];
    });
}

@end
