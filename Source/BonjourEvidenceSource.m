//
//  BonjourEvidenceSource.m
//  ControlPlane
//
//  Created by David Symonds on 27/08/07.
//
// top level bonjour browser (searches local domain for available services)
// |
// |- service level browser (looks for hosts offering service)
//   |
//   |- ._ssh._tcp 
//     |
//     |- mac1 (fully resolved service)
//     |- mac2
//   |
//   |- ._afpovertcp._tcp
//     |
//     |- mac1
//     |- mac3
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
    
    servicesBeingResolved = [[NSMutableArray alloc] init];
	
	services = [[NSMutableArray alloc] init];
    servicesByType = [[[NSMutableDictionary alloc] init] retain];
    
	hits = [[NSMutableArray alloc] init];
	hitsInProgress = [[NSMutableArray alloc] init];
    
	return self;
}

- (void)dealloc {
	[lock release];
	[topLevelNetworkBrowser release];
	[services release];
    
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
    
    [topLevelNetworkBrowser stop];
    [self clearCollectedData];

	running = NO;
	//[super stop];
}

- (void)clearCollectedData {
	//[lock lock];
    [self setDataCollected:NO];
    [services removeAllObjects];
    
    DSLog(@"clearing servicesBeingResolved");
    for (CPBonjourResolver *goingAway in servicesBeingResolved) {
        
        [goingAway stop];
        //[goingAway release];
        //[goingAway release];
        
    }
    DSLog(@"removing all objects");
    [servicesBeingResolved removeAllObjects];
    
	
    DSLog(@"clearing servicesByType");
    NSArray *keys = [servicesByType allKeys];
    for (NSString *currentKey in keys) {
        DSLog(@"clearing %@", currentKey);
        CPBonjourResolver *goingAway = [servicesByType objectForKey:currentKey];
        [goingAway stop];
        //[goingAway release];
    }
    DSLog(@"removing all objects");
    [servicesByType removeAllObjects];
	//[lock unlock];
    DSLog(@"done clearing data");
}

- (NSString *)name {
	return @"Bonjour";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule {
#ifdef DEBUG_MODE
    NSLog(@"I know about %@", services);
#endif
    
	BOOL match = NO;
    
	NSArray *comp = [[rule valueForKey:@"parameter"] componentsSeparatedByString:@"/"];
	if ([comp count] != 2)
		return NO;	// corrupted rule
	NSString *host = [comp objectAtIndex:0], *service = [comp objectAtIndex:1];
    
    NSArray *servicesSnapshot = [services copy];

	for (NSNetService *aService in servicesSnapshot) {
        if ([[aService name] isEqualToString:host] &&
            [[aService type] isEqualToString:service]) {
            match = YES;
            break;
        }
    }
    [servicesSnapshot release];

    
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

// Triggers stage 1 scanning (probing for what services are available); pass self as arg if this is the initial scan
- (void)considerScanning:(id)arg {
	if (!running)
		return;
    
    [self clearCollectedData];
    
	// This finds all service types
    [topLevelNetworkBrowser setDelegate:self];
    [topLevelNetworkBrowser setMyServiceType:@"TOP"];
	[topLevelNetworkBrowser searchForServicesOfType:@"_services._dns-sd._udp." inDomain:@""];
}


- (void) foundNewServiceFrom:(id)sender withService:(NSNetService *) service {

    // if the sender is our top level network browser then ControlPlane
    // needs to take all of the found services and create new instances
    // of CPBonjourResolver for each one.


    if (sender == topLevelNetworkBrowser) {
        // if we don't already have an NSNetService object looking for this service we 
        // create one now
        if (![servicesByType objectForKey:[NSString stringWithFormat:@"%@.%@", [service name],[CPBonjourResolver stripLocal:[service type]]]]) {
            CPBonjourResolver *tmp = [[CPBonjourResolver alloc] init];
            [tmp setDelegate:self];
            [tmp setMyServiceType:[NSString stringWithFormat:@"%@.%@", [service name],[CPBonjourResolver stripLocal:[service type]]]];
            [tmp searchForServicesOfType:[NSString stringWithFormat:@"%@.%@", [service name],[CPBonjourResolver stripLocal:[service type]]] inDomain:@"local."];
            [servicesByType setObject:tmp forKey:[NSString stringWithFormat:@"%@.%@", [service name],[CPBonjourResolver stripLocal:[service type]]]];
            [tmp release];
        }
    }
    else {
        CPBonjourResolver *tmp = [[CPBonjourResolver alloc] init];
        [tmp setDelegate:self];
        [tmp setMyServiceType:[NSString stringWithFormat:@"%@.%@", [service name],[CPBonjourResolver stripLocal:[service type]]]];
        [tmp doResolveForService:service];
        [servicesBeingResolved addObject:tmp];
        [tmp release];
    }

}

- (void) resolvedServiceArrived:(id)sender {
    dataCollected = YES;
#if DEBUG_MODE
    DSLog(@"adding %@ on %@", [(NSNetService *)sender type], [(NSNetService *) sender name]);
#endif
    [services addObject:sender];
}

- (void) netServiceBrowser:(id)netServiceBrowser removedService:(NSNetService *)removedService {
#if DEBUG_MODE
    DSLog(@"removing %@ on %@", [removedService type], [removedService name]);
#endif
    [services removeObject:removedService];
}

- (NSString *) friendlyName {
    return NSLocalizedString(@"Bonjour", @"");
}

@end
