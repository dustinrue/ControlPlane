//
//  BonjourEvidenceSource.m
//  ControlPlane
//
//  Created by David Symonds on 27/08/07.
//

#import "BonjourEvidenceSource.h"
#import "DSLogger.h"
#import "NSTimer+Invalidation.h"
#import "CPBonjourResolver.h"

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
	
	scanTimer = nil;
	stage = 0;
	topLevelNetworkBrowser = [[CPBonjourResolver alloc] init];
    cpBonjourResolvers  = [[NSMutableArray alloc] init];
	
	services = [[NSMutableArray alloc] init];

	hits = [[NSMutableArray alloc] init];
	hitsInProgress = [[NSMutableArray alloc] init];

	return self;
}

- (void)dealloc
{
	[lock release];
	[topLevelNetworkBrowser release];
	[services release];

	[hits release];
	[hitsInProgress release];

	[super dealloc];
}

- (void)start
{
	if (running)
		return;
    [super start];
    
	[self considerScanning:self];

	
}

- (void)stop
{
	if (!running)
		return;

	[topLevelNetworkBrowser stop];
    
    for (CPBonjourResolver *goingAway in cpBonjourResolvers) {
        [goingAway stop];
        [goingAway release];
    }
    
    //[topLevelNetworkBrowser release];

	[super stop];
}

- (void)doUpdate
{
   
	NSLog(@"I know about %@", services);
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
    
	NSArray *comp = [[rule valueForKey:@"parameter"] componentsSeparatedByString:@"/"];
	if ([comp count] != 2)
		return NO;	// corrupted rule
	NSString *host = [comp objectAtIndex:0], *service = [comp objectAtIndex:1];

	[lock lock];
	NSEnumerator *en = [hits objectEnumerator];
	NSDictionary *hit;
	while ((hit = [en nextObject])) {
		if ([[hit valueForKey:@"host"] isEqualToString:host] &&
		    [[hit valueForKey:@"service"] isEqualToString:service]) {
			match = YES;
			break;
		}
	}
	[lock unlock];

	return match;
}

- (NSString *)getSuggestionLeadText:(NSString *)type
{
	return NSLocalizedString(@"The presence of", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions
{
	[lock lock];
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:[services count]];
    for (NSNetService *aService in services) {
		NSString *desc = [NSString stringWithFormat:@"%@ on %@", [aService type], [aService hostName]];
		NSString *param = [NSString stringWithFormat:@"%@/%@", [aService hostName], [aService type]];
		[arr addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                        @"Bonjour", @"type",
                        param, @"parameter",
                        desc, @"description", nil]];
    }

	[lock unlock];

	return arr;
}

// Triggers stage 1 scanning (probing for services); pass self as arg if this is the initial scan
- (void)considerScanning:(id)arg
{
	if (!running)
		return;

    [cpBonjourResolvers removeAllObjects];
	[services removeAllObjects];

	// This finds all service types
    [topLevelNetworkBrowser setDelegate:self];
	[topLevelNetworkBrowser searchForServicesOfType:@"_services._dns-sd._udp." inDomain:@""];
}

// Forces an end to stage 2 scanning
- (void)finishScanning:(id)arg
{
	stage = 0;
#ifdef DEBUG_MODE
	//DSLog(@"Found %d services offered", [hitsInProgress count]);
#endif
	[lock lock];
	[hits setArray:hitsInProgress];
	[self setDataCollected:[hits count] > 0];
	[lock unlock];
}

- (void)runNextStage2Scan:(id)arg
{
	[topLevelNetworkBrowser stop];
	scanTimer = nil;

	// Send off scan for the next service we heard about during stage 1
	if ([services count] == 0) {
		[self finishScanning:nil];
		return;
	}
	NSString *service = [services objectAtIndex:0];
	[topLevelNetworkBrowser searchForServicesOfType:service inDomain:@""];
	[services removeObjectAtIndex:0];
#ifdef DEBUG_MODE
	//NSLog(@"Sent probe for hosts offering service %@", service);
#endif
	scanTimer = [[NSTimer scheduledTimerWithTimeInterval: (NSTimeInterval) 1
												  target: self
												selector: @selector(runNextStage2Scan:)
												userInfo: nil
												 repeats: NO] retain];
}


- (void) foundItemsDidChange:(id)sender {
    
    // if the sender is our top level network browser then ControlPlane
    // needs to take all of the found services and create new instances
    // of CPBonjourResolver for each one.  This 
    if (sender == topLevelNetworkBrowser) {
        
        for (NSNetService *aService in [sender foundItems]) {
            CPBonjourResolver *tmp = [[[CPBonjourResolver alloc] init] retain];
            [cpBonjourResolvers addObject:tmp];
            [tmp setDelegate:self];
            [tmp searchForServicesOfType:[NSString stringWithFormat:@"%@.%@", [aService name],[CPBonjourResolver stripLocal:[aService type]]] inDomain:@"local."];
            //[tmp searchForServicesOfType:[NSString stringWithFormat:@"_adisk._tcp.", [aService name],[CPBonjourResolver stripLocal:[aService type]]] inDomain:@"local."];
            
        }
    }
    else {
        for (NSNetService *aService in [sender foundItems]) {
            //NSLog(@"found %@ on %@", [aService type], [aService hostName]);
            CPBonjourResolver *tmp = [[[CPBonjourResolver alloc] init] retain];
            [tmp setDelegate:self];
            [tmp doResolveForService:aService];
            
        }
    }
}

- (void) resolvedServiceArrived:(id)sender {
    dataCollected = YES;
    [services addObject:sender];
}

- (void) serviceRemoved:(NSNetService *)removedService {
    [services removeObject:removedService];
}

@end
