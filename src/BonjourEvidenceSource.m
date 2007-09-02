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
- (void)finishScanning:(id)arg;
- (void)runNextStage2Scan:(id)arg;

@end

#pragma mark -

@implementation BonjourEvidenceSource

- (id)init
{
	if (!(self = [super init]))
		return nil;

	lock = [[NSLock alloc] init];

	stage = 0;
	browser = [[NSNetServiceBrowser alloc] init];
	[browser setDelegate:self];
	services = [[NSMutableArray alloc] init];

	hits = [[NSMutableArray alloc] init];
	hitsInProgress = [[NSMutableArray alloc] init];

	return self;
}

- (void)dealloc
{
	[lock release];
	[browser release];
	[services release];

	[hits release];
	[hitsInProgress release];

	[super dealloc];
}

- (void)start
{
	if (running)
		return;

	[self considerScanning:self];

	[super start];
}

- (void)stop
{
	if (!running)
		return;

	[browser stop];

	[super stop];
}

- (void)doUpdate
{
	[self considerScanning:nil];
}

- (void)clearCollectedData
{
	[lock lock];
	[hits removeAllObjects];
	[self setDataCollected:NO];
	[lock unlock];
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

// Triggers stage 1 scanning (probing for services); pass self as arg if this is the initial scan
- (void)considerScanning:(id)arg
{
	if (!running && (arg != self))
		return;

	[lock lock];
	if (stage != 0) {
		[lock unlock];
		return;
	}
	stage = 1;
	[lock unlock];

	[services removeAllObjects];

	// This finds all service types
	[browser searchForServicesOfType:@"_services._dns-sd._udp." inDomain:@""];
}

// Forces an end to stage 2 scanning
- (void)finishScanning:(id)arg
{
	stage = 0;
#ifdef DEBUG_MODE
	DSLog(@"Found %d services offered", [hitsInProgress count]);
#endif
	[lock lock];
	[hits setArray:hitsInProgress];
	[lock unlock];
}

- (void)runNextStage2Scan:(id)arg
{
	[browser stop];
	scanTimer = nil;

	// Send off scan for the next service we heard about during stage 1
	if ([services count] == 0) {
		[self finishScanning:nil];
		return;
	}
	NSString *service = [services objectAtIndex:0];
	[services removeObjectAtIndex:0];
	[browser searchForServicesOfType:service inDomain:@""];
#ifdef DEBUG_MODE
	//NSLog(@"Sent probe for hosts offering service %@", service);
#endif
	scanTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval) 1
					 target:self
				       selector:@selector(runNextStage2Scan:)
				       userInfo:nil
					repeats:NO];
}

#pragma mark NSNetServiceBrowser delegate methods

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser
	   didFindService:(NSNetService *)netService
	       moreComing:(BOOL)moreServicesComing
{
	if (stage == 1) {
		// Sample data here would be:
		//	name:	_growl
		//	type:	_tcp.local.
		//	domain:	.
		NSString *service = [NSString stringWithFormat:@"%@.%@", [netService name], [netService type]];
		if ([service hasSuffix:@".local."])
			service = [service substringToIndex:([service length] - 6)];
#ifdef DEBUG_MODE
		//NSLog(@"Heard about service [%@]", service);
#endif
		[services addObject:service];
	} else if (stage == 2) {
		// Sample data here would be:
		//	name:	Serenity
		//	type:	_growl._tcp.
		//	domain:	local.
		NSDictionary *hit = [NSDictionary dictionaryWithObjectsAndKeys:
			[netService name], @"host",
			[netService type], @"service",
			nil];
#ifdef DEBUG_MODE
		NSLog(@"Found: %@", hit);
#endif
		[hitsInProgress addObject:hit];
	}

	if (moreServicesComing)
		return;

	[netServiceBrowser stop];
	if (stage == 1) {
		stage = 2;
		[hitsInProgress removeAllObjects];
		scanTimer = nil;
	}

	if (scanTimer && [scanTimer isValid])
		[scanTimer invalidate];
	[self runNextStage2Scan:nil];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser
	 didRemoveService:(NSNetService *)netService
	       moreComing:(BOOL)moreServicesComing
{
#ifdef DEBUG_MODE
	//NSLog(@"%s called.", __PRETTY_FUNCTION__);
#endif
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)netServiceBrowser
{
#ifdef DEBUG_MODE
	//NSLog(@"%s called.", __PRETTY_FUNCTION__);
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
