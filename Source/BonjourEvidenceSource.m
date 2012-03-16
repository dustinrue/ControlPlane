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

@end

#pragma mark -

@implementation BonjourEvidenceSource

- (id)init {
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

- (void)dealloc {
	[lock release];
	[topLevelNetworkBrowser release];
	[services release];
    [cpBonjourResolvers release];
    [servicesBeingResolved release];

	[hits release];
	[hitsInProgress release];

	[super dealloc];
}



- (void)start {
	if (running)
		return;
    //[super start];
    
    running = YES;
	[self considerScanning:self];

	
}

- (void)stop {
	if (!running)
		return;


    [self clearCollectedData];
    [topLevelNetworkBrowser stop];
	running = NO;
	//[super stop];
}

- (void)clearCollectedData {
	[lock lock];
    [services removeAllObjects];
    
    for (CPBonjourResolver *goingAway in cpBonjourResolvers) {
        
        [goingAway stop];
        [goingAway release];
    }
    [cpBonjourResolvers removeAllObjects];
    
    for (CPBonjourResolver *goingAway in servicesBeingResolved) {
        
        [goingAway stop];
        [goingAway release];
        
    }
    [servicesBeingResolved removeAllObjects];
    
	[self setDataCollected:NO];
	[lock unlock];
}

- (NSString *)name {
	return @"Bonjour";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule {
#if DEBUG_MODE
    NSLog(@"I know about %@", services);
#endif
    
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

- (NSString *)getSuggestionLeadText:(NSString *)type {
	return NSLocalizedString(@"The presence of", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions {
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
- (void)considerScanning:(id)arg {
	if (!running)
		return;

    [self clearCollectedData];

	// This finds all service types
    [topLevelNetworkBrowser setDelegate:self];
	[topLevelNetworkBrowser searchForServicesOfType:@"_services._dns-sd._udp." inDomain:@""];
}


- (void) foundItemsDidChange:(id)sender {
    
    // if the sender is our top level network browser then ControlPlane
    // needs to take all of the found services and create new instances
    // of CPBonjourResolver for each one.
    if (sender == topLevelNetworkBrowser) {
        [self clearCollectedData];
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

- (void) netServiceBrowser:(id)netServiceBrowser removedService:(NSNetService *)removedService {
    if (netServiceBrowser == topLevelNetworkBrowser) {
        [cpBonjourResolvers removeObject:netServiceBrowser];
    }
    else {
        [servicesBeingResolved removeObject:netServiceBrowser];
    }
    NSLog(@"%@ is removing %@",netServiceBrowser, [removedService name]);
    [services removeObject:removedService];
}

- (NSString *) friendlyName {
    return NSLocalizedString(@"Bonjour", @"");
}

@end
