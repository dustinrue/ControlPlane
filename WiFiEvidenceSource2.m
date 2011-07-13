//
//  WiFiEvidenceSource2.m
//  MarcoPolo
//
//  Created by Dustin Rue on 7/10/11.
//  
//

#import <CoreWLAN/CoreWLAN.h>
#import "WiFiEvidenceSource2.h"


@implementation WiFiEvidenceSource2

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

- (void)doUpdate
{
	NSMutableArray *all_aps = [NSMutableArray array];
    
	if (!WirelessIsAvailable())
		goto end_of_scan;
    
//	WirelessContextPtr wctxt = 0;
//	WirelessInfo info;
	NSArray *list = nil;
	NSString *mac_to_skip = nil;
	BOOL do_scan = YES;
//	WIErr err;
    
//	if ((err = WirelessAttach(&wctxt, 0)) != noErr) {
#ifdef DEBUG_MODE
//		NSLog(@"%@ >> WirelessAttached failed with error code 0x%08x", [self class], err);
#endif
	//	goto end_of_scan;
	//}
    
	// First, check to see if we're already associated
//	if ((WirelessGetInfo(wctxt, &info) == noErr) && (info.power > 0) && (info.link_qual > 0)) {
//		NSString *ssid = [NSString stringWithCString:(const char *) info.name
//                                            encoding:NSISOLatin1StringEncoding];
//		NSString *mac = macToString(info.macAddress);
//		mac_to_skip = mac;
//		[all_aps addObject:[NSDictionary dictionaryWithObjectsAndKeys:
//                            ssid, @"SSID", mac, @"MAC", nil]];
//		do_scan = NO;
//	}
    
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"WiFiAlwaysScans"])
		do_scan = YES;
	if (wakeUpCounter > 0) {
		do_scan = YES;
		--wakeUpCounter;
	}
    
	NSError *err = nil;
    CWNetwork *currentNetwork = nil;
	NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:nil];
    
    //NSLog(@"Attempting to do the scan");
    NSArray *supportedInterfaces = [CWInterface supportedInterfaces];
    self.currentInterface = [CWInterface interfaceWithName:[supportedInterfaces objectAtIndex:0]];
    
    self.scanResults = [NSMutableArray arrayWithArray:[self.currentInterface scanForNetworksWithParameters:params error:&err]];
    
  	if( err )
		NSLog(@"error: %@",err);
	else
		[self.scanResults sortUsingDescriptors:[NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:@"ssid" ascending:YES selector:@selector	(caseInsensitiveCompare:)] autorelease]]];
    
    
    for (currentNetwork in self.scanResults) {
        [all_aps addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                               [currentNetwork ssid], @"SSID", [currentNetwork bssid], @"MAC", nil]];
        //NSLog(@"found ssid %@ with bssid %@ and RSSI %@",[currentNetwork ssid], [currentNetwork bssid], [currentNetwork rssi]);
    }

    
	NSEnumerator *en = [list objectEnumerator];
//	const WirelessNetworkInfo *ap;
	NSData *data;
	while ((data = [en nextObject])) {
//		ap = (const WirelessNetworkInfo *) [data bytes];
		// XXX: I'm not sure about the string encoding here...
//		NSString *ssid = [NSString stringWithCString:(const char *) ap->name
  //                                          encoding:NSISOLatin1StringEncoding];
	//	NSString *mac = macToString(ap->macAddress);
        
	//	if (mac_to_skip && [mac_to_skip isEqualToString:mac])
	//		continue;
        
	//	[all_aps addObject:[NSDictionary dictionaryWithObjectsAndKeys:
     //                       ssid, @"SSID", mac, @"MAC", nil]];
	}
    
	//WirelessDetach(wctxt);
    
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
	return @"WiFi2";
}

- (NSArray *)typesOfRulesMatched
{
	return [NSArray arrayWithObjects:@"MAC", @"SSID", nil];
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
	if ([type isEqualToString:@"MAC"])
		return NSLocalizedString(@"A WiFi access point with a MAC of", @"In rule-adding dialog");
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
		NSString *mac = [dict valueForKey:@"MAC"], *ssid = [dict valueForKey:@"SSID"];
		[arr addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                        @"MAC", @"type",
                        mac, @"parameter",
                        [NSString stringWithFormat:@"%@ (%@)", mac, ssid], @"description", nil]];
		[arr addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                        @"SSID", @"type",
                        ssid, @"parameter",
                        ssid, @"description", nil]];
	}
    
	[lock unlock];
    
	return arr;
}



@end
