//
//  BonjourEvidenceSource.m
//  MarcoPolo
//
//  Created by David Symonds on 27/08/07.
//

#import "BonjourEvidenceSource.h"
#import "DSLogger.h"


@interface BonjourEvidenceSource (Private)

- (void)considerScanning:(id)arg;

@end

#pragma mark -

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

	running = YES;

	[self considerScanning:nil];
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

- (void)considerScanning:(id)arg
{
	if (!running)
		return;

	// This should find all service types
	[browser searchForServicesOfType:@"_services._dns-sd._udp." inDomain:@""];
}

#pragma mark NSNetServiceBrowser delegate methods

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser
	   didFindService:(NSNetService *)netService
	       moreComing:(BOOL)moreServicesComing
{
#ifdef DEBUG_MODE
	NSLog(@"Found: %@/%@/%@", [netService name], [netService type], [netService domain]);
#endif

	if (!moreServicesComing) {
		[netServiceBrowser stop];

		// Schedule a new scan in 5 seconds
#ifdef DEBUG_MODE
		NSLog(@"--> sched+5");
#endif
		[NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval) 5
						 target:self
					       selector:@selector(considerScanning:)
					       userInfo:nil
						repeats:NO];
	}
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

@end
