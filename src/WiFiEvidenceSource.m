//
//  WiFiEvidenceSource.m
//  MarcoPolo
//
//  Created by David Symonds on 29/03/07.
//

#import "Apple80211.h"
#import "WiFiEvidenceSource.h"


@implementation WiFiEvidenceSource

- (id)init
{
	if (!(self = [super init]))
		return nil;

	lock = [[NSLock alloc] init];
	apList = [[NSMutableArray alloc] init];

	return self;
}

- (void)dealloc
{
	[super blockOnThread];

	[lock dealloc];
	[apList dealloc];

	[super dealloc];
}

static NSString *macToString(const UInt8 *mac)
{
	return [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x",
		mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]];
}

- (void)doUpdate
{
	NSMutableArray *all_aps = [NSMutableArray array];

	if (!sourceEnabled)
		goto end_of_scan;

	if (!WirelessIsAvailable())
		goto end_of_scan;

	WirelessContextPtr wctxt = 0;
	WirelessInfo info;
	NSArray *list = nil;
	NSString *mac_to_skip = nil;
	BOOL do_scan = YES;

	if (WirelessAttach(&wctxt, 0) != noErr)
		goto end_of_scan;

	// First, check to see if we're already associated
	if ((WirelessGetInfo(wctxt, &info) == noErr) && (info.power > 0) && (info.link_qual > 0)) {
		NSString *ssid = [NSString stringWithCString:(const char *) info.name
						    encoding:NSISOLatin1StringEncoding];
		NSString *mac = macToString(info.macAddress);
		mac_to_skip = mac;
		[all_aps addObject:[NSDictionary dictionaryWithObjectsAndKeys:
					ssid, @"SSID", mac, @"MAC", nil]];
		do_scan = NO;
	}

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"WiFiAlwaysScans"] || (wakeUpCounter > 0))
		do_scan = YES;

	// NOTE: Use WirelessScanSplit if we want to cleanly ignore ad-hoc networks
	// NOTE: won't return duplicate SSIDs
	if (do_scan && (WirelessScan(wctxt, (CFArrayRef *) &list, 1) != noErr)) {
		WirelessDetach(wctxt);
		goto end_of_scan;
	}
	if (do_scan && !list) {
		WirelessDetach(wctxt);
		goto end_of_scan;
	}

	NSEnumerator *en = [list objectEnumerator];
	const WirelessNetworkInfo *ap;
	NSData *data;
	while ((data = [en nextObject])) {
		ap = (const WirelessNetworkInfo *) [data bytes];
		// XXX: I'm not sure about the string encoding here...
		NSString *ssid = [NSString stringWithCString:(const char *) ap->name
						    encoding:NSISOLatin1StringEncoding];
		NSString *mac = macToString(ap->macAddress);

		if (mac_to_skip && [mac_to_skip isEqualToString:mac])
			continue;

		[all_aps addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			ssid, @"SSID", mac, @"MAC", nil]];
	}

	//[list release];	// XXX: Release or not? Hrm...
	WirelessDetach(wctxt);

end_of_scan:
	[lock lock];
	[apList setArray:all_aps];
	[self setDataCollected:[apList count] > 0];
#ifdef DEBUG_MODE
	if (sourceEnabled)
		NSLog(@"%@ >> %@", [self class], apList);
#endif
	[lock unlock];
}

- (NSString *)name
{
	return @"WiFi";
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
