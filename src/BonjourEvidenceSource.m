//
//  BonjourEvidenceSource.m
//  MarcoPolo
//
//  Created by David Symonds on 27/08/07.
//

//#import <IOBonjour/objc/IOBonjourDevice.h>
//#import <IOBonjour/objc/IOBonjourDeviceInquiry.h>

#import "BonjourEvidenceSource.h"
#import "DSLogger.h"


@implementation BonjourEvidenceSource

- (id)init
{
	if (!(self = [super init]))
		return nil;

	lock = [[NSLock alloc] init];
	services = [[NSMutableArray alloc] init];

	browser = [[NSNetServiceBrowser alloc] init];
	[browser setDelegate:self];

	return self;
}

- (void)dealloc
{
	[lock release];
	[services release];
	[browser release];

	[super dealloc];
}

- (void)start
{
	if (running)
		return;

	// XXX: probably need to specify the correct service type here
	//[browser searchForServicesOfType:@"_http._tcp" inDomain:@""];
	[browser searchForBrowsableDomains];

	running = YES;
}

- (void)stop
{
	if (!running)
		return;

	[browser stop];

	[lock lock];
	[services removeAllObjects];
	[self setDataCollected:NO];
	[lock unlock];

	running = NO;
}

- (NSString *)name
{
	return @"Bonjour";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule
{
	BOOL match = NO;

	// TODO
//	[lock lock];
//	NSEnumerator *en = [services objectEnumerator];
//	NSDictionary *dev;
//	NSString *mac = [rule objectForKey:@"parameter"];
//	while ((dev = [en nextObject])) {
//		if ([[dev valueForKey:@"mac"] isEqualToString:mac]) {
//			match = YES;
//			break;
//		}
//	}
//	[lock unlock];

	return match;
}

- (NSString *)getSuggestionLeadText:(NSString *)type
{
	return NSLocalizedString(@"The presence of", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions
{
	NSMutableArray *arr = [NSMutableArray arrayWithCapacity:[services count]];

	// TODO
//	[lock lock];
//	NSEnumerator *en = [devices objectEnumerator];
//	NSDictionary *dev;
//	while ((dev = [en nextObject])) {
//		NSString *name = [dev valueForKey:@"device_name"];
//		if (!name)
//			name = NSLocalizedString(@"(Unnamed device)", @"String for unnamed devices");
//		NSString *vendor = [dev valueForKey:@"vendor_name"];
//		if (!vendor)
//			vendor = @"?";
//
//		NSString *desc = [NSString stringWithFormat:@"%@ [%@]", name, vendor];
//		[arr addObject:[NSDictionary dictionaryWithObjectsAndKeys:
//			@"Bonjour", @"type",
//			[dev valueForKey:@"mac"], @"parameter",
//			desc, @"description", nil]];
//	}
//	[lock unlock];

	return arr;
}

#pragma mark NSNetServiceBrowser delegate methods

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser
	   didFindService:(NSNetService *)netService
	       moreComing:(BOOL)moreServicesComing
{
#ifdef DEBUG_MODE
	NSLog(@"%s called.", __PRETTY_FUNCTION__);
#endif
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser
	 didRemoveService:(NSNetService *)netService
	       moreComing:(BOOL)moreServicesComing
{
#ifdef DEBUG_MODE
	NSLog(@"%s called.", __PRETTY_FUNCTION__);
#endif
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)netServiceBrowser
{
#ifdef DEBUG_MODE
	NSLog(@"%s called.", __PRETTY_FUNCTION__);
#endif
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser
	     didNotSearch:(NSDictionary *)errorInfo
{
#ifdef DEBUG_MODE
	NSLog(@"%s called:\n%@", __PRETTY_FUNCTION__, errorInfo);
#endif
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser
	    didFindDomain:(NSString *)domainName
	       moreComing:(BOOL)moreDomainsComing
{
#ifdef DEBUG_MODE
	NSLog(@"%s called: %@ (more=%d)", __PRETTY_FUNCTION__, domainName, moreDomainsComing);
#endif
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser
	  didRemoveDomain:(NSString *)domainName
	       moreComing:(BOOL)moreDomainsComing
{
#ifdef DEBUG_MODE
	NSLog(@"%s called: %@ (more=%d)", __PRETTY_FUNCTION__, domainName, moreDomainsComing);
#endif
}

@end
