//
//  WiFiEvidenceSource2.m
//  MarcoPolo
//
//  Created by Dustin Rue on 7/10/11.
//  Copyright 2011 Dustin Rue. All rights reserved.
//  
//

#import <CoreWLAN/CoreWLAN.h>
#import "CoreWLANEvidenceSource.h"


@implementation WiFiEvidenceSourceCoreWLAN

@synthesize currentInterface;
@synthesize scanResults;
@synthesize ssidString;
@synthesize signalStrength;
@synthesize macAddress;

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
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

static NSString *macToString(const UInt8 *mac)
{
	return [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x",
            mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]];
}

- (bool)isWirelessAvailable {
    BOOL powerState = self.currentInterface.power;
    return powerState;
}

- (void)doUpdate
{
	NSMutableArray *all_aps = [NSMutableArray array];
       

	BOOL do_scan = YES;

    
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"WiFiAlwaysScans"])
		do_scan = YES;
	if (wakeUpCounter > 0) {
		do_scan = YES;
		--wakeUpCounter;
	}
    
	NSError *err = nil;
    CWNetwork *currentNetwork = nil;
	NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:nil];
    
#ifdef DEBUG_MODE
    NSLog(@"Attempting to do the scan");
#endif
    
    NSArray *supportedInterfaces = [CWInterface supportedInterfaces];
    self.currentInterface = [CWInterface interfaceWithName:[supportedInterfaces objectAtIndex:0]];
    
    if ([self isWirelessAvailable]) { 
    
        self.scanResults = [NSMutableArray arrayWithArray:[self.currentInterface scanForNetworksWithParameters:params error:&err]];
        
        if( err )
            NSLog(@"error: %@",err);
        else
            [self.scanResults sortUsingDescriptors:[NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:@"ssid" ascending:YES selector:@selector	(caseInsensitiveCompare:)] autorelease]]];
        
        
        for (currentNetwork in self.scanResults) {
            [all_aps addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                   [currentNetwork ssid], @"WiFi SSID", [currentNetwork bssid], @"WiFi BSSID", nil]];
    #ifdef DEBUG_MODE
            NSLog(@"found ssid %@ with bssid %@ and RSSI %@",[currentNetwork ssid], [currentNetwork bssid], [currentNetwork rssi]);
    #endif
        }

    }
    else {
#ifdef DEBUG_MODE
        NSLog(@"wifi disabled, no scan done");
#endif
    }
    
end_of_scan:
	[lock lock];
	[apList setArray:all_aps];
	[self setDataCollected:[apList count] > 0];
#ifdef DEBUG_MODE
	NSLog(@"%@ >> %@", [self class], apList);
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
    
	[lock lock];
	NSEnumerator *en = [apList objectEnumerator];
	NSDictionary *dict;
	while ((dict = [en nextObject])) {
		NSString *x = [dict valueForKey:key];
		if ([param isEqualToString:x]) {
			match = YES;
			break;
		}
	}
	[lock unlock];
    
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



@end
