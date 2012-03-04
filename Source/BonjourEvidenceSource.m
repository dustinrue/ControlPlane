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
    servicesBeingResolved = [[NSMutableArray alloc] init];
	
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
    [cpBonjourResolvers release];
    [servicesBeingResolved release];

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
    
    [services removeAllObjects];
    
    for (CPBonjourResolver *goingAway in cpBonjourResolvers) {
        
        [goingAway stop];
        
        while ([goingAway retainCount] > 1) {
            [goingAway release];
        }
        
        
    }
    [cpBonjourResolvers removeAllObjects];
    
    for (CPBonjourResolver *aService in servicesBeingResolved) {
        
        [aService stop];
        while ([aService retainCount] > 1) {
            [aService release];
        }

        
    }
    [servicesBeingResolved removeAllObjects];


    
    //[services removeAllObjects];
    
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
	for (NSNetService *aService in services) {
        if ([[aService name] isEqualToString:host] &&
            [[aService type] isEqualToString:service]) {
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
		NSString *desc = [NSString stringWithFormat:@"%@ on %@", [aService type], [CPBonjourResolver stripLocal:[aService name]]];
		NSString *param = [NSString stringWithFormat:@"%@/%@", [aService name], [aService type]];
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
    NSLog(@"service has %@ objects", [services count]);
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
            
        }
    }
    else {
        for (NSNetService *aService in [sender foundItems]) {
            CPBonjourResolver *tmp = [[[CPBonjourResolver alloc] init] retain];
            [tmp setDelegate:self];
            [tmp doResolveForService:aService];
            [servicesBeingResolved addObject:tmp];
            
        }
    }
}

- (void) resolvedServiceArrived:(id)sender {
    dataCollected = YES;
    [services addObject:sender];
}

- (void) serviceRemoved:(NSNetService *)removedService {
    [services removeObject:removedService];
    [removedService release];
}

@end
