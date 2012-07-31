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
#import "DSLogger.h"


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
    BOOL powerState = [self.currentInterface powerOn];
    return powerState;
}

- (void)doUpdate
{
    
	NSMutableArray *all_aps = [NSMutableArray array];
	NSError *err = nil;
    CWNetwork *currentNetwork = nil;
    NSArray *supportedInterfaces = [[CWInterface interfaceNames] allObjects];

	BOOL do_scan = YES;

    
#ifdef DEBUG_MODE
    DSLog(@"Attempting to do the scan");
#endif
    
    // get a list of supported Wi-Fi interfaces.  It is unlikely, but still possible, for there to
    // be more than one interface, yet this assumes there is just one
    @try {
        self.currentInterface = [CWInterface interfaceWithName:[supportedInterfaces objectAtIndex:0]];
    }
    @catch (NSException *exception) {
        DSLog(NSLocalizedString(@"This Mac doesn't appear to have WiFi or your WiFi card has failed",@"The Mac does not have a Wifi/AirPort card or it has failed"));
    }

    
    
    // first see if Wi-Fi is even turned on
    if (! [self.currentInterface powerOn]) {
        [self clearCollectedData];
#ifdef DEBUG_MODE
        DSLog(@"wifi disabled, no scan done");
#endif
        return;
    }
    
    // see if we are currently connected to an AP
    NSString *currentSSID = [self.currentInterface ssid];
    

    // wakeUpCounter will be set to 2 after a wake event.  Since
    // the machine can't be associated yet we can afford to scan
    // a couple of times.  This might not be needed any longer and might
    // even be detrimental with newer versions of OS X that promise to 
    // scan for and connect to wifi networks more quickly.
    if (wakeUpCounter > 0) {
		do_scan = YES;
		--wakeUpCounter;
	}
    // don't scan if currentSSID is set (Wi-Fi is associated with something)
    // and the WiFiAlwaysScans is set to false
    else if (currentSSID && ![[NSUserDefaults standardUserDefaults] boolForKey:@"WiFiAlwaysScans"])
        do_scan = NO;
    else
        do_scan = YES;


    // if do_scan is set to yes, do the Wi-Fi scan
    if (do_scan) { 
    
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

    }
    else {
        // if do_scan is false but we're still here, then we're associated
        // We still need to fill in the scanResults variable so rather than
        // doing so with a scan we ask CoreWLAN to tell us about what 
        // we're connected to, ControlPlane can then see if the associated
        // network matches a rule
#ifdef DEBUG_MODE
        DSLog(@"already associated with an AP, using connection info");
#endif
        [all_aps addObject:[NSDictionary dictionaryWithObjectsAndKeys:self.currentInterface.ssid, @"WiFi SSID", self.currentInterface.bssid, @"WiFi BSSID", nil]];

    }
    
	[lock lock];
	//[apList setArray:all_aps];
    
    // merge the results rather than simply replacing
    // the apList array with new results
    if ([apList mergeWith:all_aps] ) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"evidenceSourceDataDidChange" object:nil];
    }
	[self setDataCollected:[apList count] > 0];
#ifdef DEBUG_MODE
	//DSLog(@"%@ >> %@", [self class], apList);
#endif
	[lock unlock];
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


@end
