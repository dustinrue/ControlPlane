//
//  WiFiEvidenceSource2.m
//  ControlPlane
//
//  Created by Dustin Rue on 7/10/11.
//  Copyright 2011 Dustin Rue. All rights reserved.
//  
//

#import <CoreWLAN/CoreWLAN.h>
#import "CoreWLANEvidenceSource.h"
#import "NSMutableArray+Merge.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import "DSLogger.h"

#pragma mark C callbacks

static void linkDataChanged(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info) {

    WiFiEvidenceSourceCoreWLAN *src = (WiFiEvidenceSourceCoreWLAN *) info;
    [src getInterfaceStateInfo];

}

@implementation WiFiEvidenceSourceCoreWLAN

@synthesize currentInterface;
@synthesize scanResults;
@synthesize ssidString;
@synthesize signalStrength;
@synthesize macAddress;

- (id)init
{
    self = [super init];
    if (!self)
		return nil;
    
    lock = [[NSLock alloc] init];
	apList = [[NSMutableArray alloc] init];
	wakeUpCounter = 0;
	
    return self;
}

- (void)dealloc
{
    [lock release];
	[apList release];
    [super dealloc];
}

- (void)wakeFromSleep:(id)arg
{
	[super wakeFromSleep:arg];
    
	wakeUpCounter = 2;
}

- (bool)isWirelessAvailable {
    if (self.currentInterface == nil)
        return NO;

    return [self.currentInterface powerOn];
}

- (void)doUpdate:(NSTimer *)timer {
    DSLog(@"timer fired");
    [self doUpdate];
}

- (void)doUpdate {
    
	NSMutableArray *all_aps = [NSMutableArray array];
    
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
    
    // check to see if the interface is active
    if (!self.linkActive || [[NSUserDefaults standardUserDefaults] boolForKey:@"WiFiAlwaysScans"]) {
        DSLog(@"WiFi link is inactive, doing full scan");
        all_aps = [self scanForNetworks];
    }
    else {
        DSLog(@"WiFi link is active, grabbing connection info");
        [all_aps addObject:[NSDictionary dictionaryWithObjectsAndKeys:self.currentInterface.ssid, @"WiFi SSID", self.currentInterface.bssid, @"WiFi BSSID", nil]];
    }

    [self toggleUpdateLoop:nil];
	[lock lock];

    if ([apList mergeWith:all_aps]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"evidenceSourceDataDidChange" object:nil];
    }
    
	[self setDataCollected:[apList count] > 0];
#ifdef DEBUG_MODE
	//DSLog(@"%@ >> %@", [self class], apList);
#endif
	[lock unlock];
}

- (NSMutableArray *)scanForNetworks {
    
    NSError *err = nil;
    NSMutableArray *all_aps = [NSMutableArray array];
    CWInterface *currentNetwork = nil;
    
    self.scanResults = [NSMutableArray arrayWithArray:[[self.currentInterface scanForNetworksWithName:nil error:&err] allObjects]];
    
    if( err )
        DSLog(@"error: %@",err);
    else
        [self.scanResults sortUsingDescriptors:[NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:@"ssid" ascending:YES selector:@selector	(caseInsensitiveCompare:)] autorelease]]];
    
    
    for (currentNetwork in self.scanResults) {
        [all_aps addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                            [currentNetwork ssid], @"WiFi SSID", [currentNetwork bssid], @"WiFi BSSID", nil]];
#ifdef DEBUG_MODE
        DSLog(@"found ssid %@ with bssid %@ and RSSI %ld",[currentNetwork ssid], [currentNetwork bssid], [currentNetwork rssiValue]);
#endif
    }
    
    return all_aps;
}

- (void)clearCollectedData
{
	[lock lock];
	[apList removeAllObjects];
	[self setDataCollected:NO];
	[lock unlock];
}

- (NSString *)name
{
	return @"WiFi";
}

- (NSArray *)typesOfRulesMatched
{
	return [NSArray arrayWithObjects:@"WiFi BSSID", @"WiFi SSID", nil];
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule
{
	BOOL match = NO;
	NSString *key = [rule valueForKey:@"type"];
	NSString *param = [rule valueForKey:@"parameter"];
    
	//[lock lock];
    NSArray *tmp = [apList copy];
	NSEnumerator *en = [tmp objectEnumerator];
	NSDictionary *dict;
	while ((dict = [en nextObject])) {
		NSString *x = [dict valueForKey:key];
#ifdef DEBUG_MODE
        DSLog(@"checking to see if %@ matches",[dict valueForKey:key]);
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

- (NSString *)getSuggestionLeadText:(NSString *)type
{
	if ([type isEqualToString:@"WiFi BSSID"])
		return NSLocalizedString(@"A WiFi access point with a BSSID of", @"In rule-adding dialog");
	else
		return NSLocalizedString(@"A WiFi access point with an SSID of", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions
{
	NSMutableArray *arr = [NSMutableArray array];
	NSEnumerator *en;
	NSDictionary *dict;
    
	[lock lock];
    
	en = [apList objectEnumerator];
	while ((dict = [en nextObject])) {
		NSString *mac = [dict valueForKey:@"WiFi BSSID"], *ssid = [dict valueForKey:@"WiFi SSID"];
		[arr addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                        @"WiFi BSSID", @"type",
                        mac, @"parameter",
                        [NSString stringWithFormat:@"%@ (%@)", mac, ssid], @"description", nil]];
		[arr addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                        @"WiFi SSID", @"type",
                        ssid, @"parameter",
                        ssid, @"description", nil]];
	}
    
	[lock unlock];
    
	return arr;
}

- (NSString *) friendlyName {
    return NSLocalizedString(@"Nearby WiFi Network", @"");
}

- (void) startUpdateLoop {
    
    if (self.loopTimer)
        return;
    
    self.loopTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval) 10
                                                 target:self
                                               selector:@selector(doUpdate:)
                                               userInfo:nil
                                                repeats:YES];

}

- (void) stopUpdateLoop {
    [self.loopTimer invalidate];
    self.loopTimer = nil;
}

- (void) toggleUpdateLoop:(NSNotification *)notification {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"WiFiAlwaysScans"] || !self.linkActive) {
        [self startUpdateLoop];
    }
    else {
        [self stopUpdateLoop];
    }
}
- (void) start {
    if (running) return;        

    
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(toggleUpdateLoop:)
												 name:NSUserDefaultsDidChangeNotification
											   object:nil];
     
    
    // attempt to get the current 
    if (![self getWiFiInterface])
        return;
    
    
    if (![self registerForAsyncNotifications])
        return;
    
    
    [self getInterfaceStateInfo];
    
    [self doUpdate];
    
    [self toggleUpdateLoop:nil];

    running = YES;
}

- (void) stop {
    
    if (running)
        running = NO;
    
    [self clearCollectedData];
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), _runLoop, kCFRunLoopCommonModes);

    [self stopUpdateLoop];
    
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

    
    self.currentInterface = [CWInterface interfaceWithName:[supportedInterfaces objectAtIndex:0]];
    self.interfaceBSDName = [self.currentInterface interfaceName];
    
    DSLog(@"currentInterface %@\nBSD name %@", self.currentInterface, self.interfaceBSDName);
    
    return YES;
}

- (BOOL) registerForAsyncNotifications {
    // Register for asynchronous notifications
	
	_ctxt.version = 0;
	_ctxt.info = self;
	_ctxt.retain = NULL;
	_ctxt.release = NULL;
	_ctxt.copyDescription = NULL;
    
	self.store = SCDynamicStoreCreate(NULL, CFSTR("ControlPlane"), linkDataChanged, &_ctxt);
	_runLoop = SCDynamicStoreCreateRunLoopSource(NULL, self.store, 0);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), _runLoop, kCFRunLoopCommonModes);
	NSArray *keys = [NSArray arrayWithObjects:
                     [NSString stringWithFormat:@"State:/Network/Interface/%@/AirPort", self.interfaceBSDName],
                     [NSString stringWithFormat:@"State:/Network/Interface/%@/Link", self.interfaceBSDName],
                     nil];
    

	return SCDynamicStoreSetNotificationKeys(self.store, (CFArrayRef) keys, NULL);
}

- (void) dumpData {
    BOOL isActive = [[self.interfaceData valueForKey:@"Busy"] boolValue];
    DSLog(@"interface data %@", self.interfaceData);
    DSLog(@"interface is %@", (isActive) ? @"busy":@"not busy");
    DSLog(@"interface is %@", (self.linkActive) ? @"active":@"inactive");
}

- (void) getInterfaceStateInfo {

    NSDictionary *currentData = nil;
    
    currentData = SCDynamicStoreCopyValue(self.store, (CFStringRef)[NSString stringWithFormat:@"State:/Network/Interface/%@/Link", self.interfaceBSDName]);
    [self setLinkActive:[[currentData valueForKey:@"Active"] boolValue]];
    [currentData release];
    
    currentData = SCDynamicStoreCopyValue(self.store, (CFStringRef)[NSString stringWithFormat:@"State:/Network/Interface/%@/AirPort", self.interfaceBSDName]);
    [self setInterfaceData:currentData];
    [currentData release];
    
    //[self dumpData];
    [self doUpdate];
}


@end
