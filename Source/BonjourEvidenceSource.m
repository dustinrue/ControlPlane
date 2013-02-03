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

@synthesize lock;
@synthesize scanTimer;
@synthesize stage;
@synthesize topLevelNetworkBrowser;
@synthesize servicesBeingResolved;
@synthesize services;
@synthesize servicesByType;
@synthesize hits;
@synthesize hitsInProgress;

- (id)init {
    self = [super init];
    
    if (!self)
        return self;
    
	lock = [[NSLock alloc] init];
	
	scanTimer = nil;
	stage = 0;
	topLevelNetworkBrowser = [[CPBonjourResolver alloc] init];
    
    servicesBeingResolved = [[NSMutableArray alloc] init];
	
	services = [[NSMutableArray alloc] init];
    servicesByType = [[NSMutableDictionary alloc] init];
    
	hits = [[NSMutableArray alloc] init];
	hitsInProgress = [[NSMutableArray alloc] init];
    
	return self;
}

- (void)dealloc {
    /*
	[lock release];
    [scanTimer release];
    [servicesBeingResolved release];
	[topLevelNetworkBrowser release];
	[services release];
    
    [servicesBeingResolved release];
    
	[hits release];
	[hitsInProgress release];
    
	[super dealloc];
     */
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
    
    [self.topLevelNetworkBrowser stop];
    [self clearCollectedData];

	running = NO;
	//[super stop];
}

- (void)clearCollectedData {
	//[lock lock];
    [self setDataCollected:NO];
    
    NSMutableArray *toBeCleared = [self.services mutableCopy];
    [toBeCleared removeAllObjects];
    
    self.services = toBeCleared;


    for (CPBonjourResolver *goingAway in self.servicesBeingResolved) {
        
        [goingAway stop];
        
    }
    //DSLog(@"removing all objects");
    toBeCleared = [self.servicesBeingResolved mutableCopy];
    [toBeCleared removeAllObjects];
    
    self.servicesBeingResolved = toBeCleared;
    
	
    //DSLog(@"clearing servicesByType");
    NSArray *keys = [self.servicesByType allKeys];
    for (NSString *currentKey in keys) {
        //DSLog(@"clearing %@", currentKey);
        CPBonjourResolver *goingAway = [self.servicesByType objectForKey:currentKey];
        [goingAway stop];

    }
    //DSLog(@"removing all objects");
    [self.servicesByType removeAllObjects];
	//[lock unlock];
    //DSLog(@"done clearing data");
}

- (NSString *)name {
	return @"Bonjour";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule {
    BOOL match = NO;
    @synchronized(self) {
    #ifdef DEBUG_MODE
        NSLog(@"I know about %@", self.services);
    #endif
        

        
        NSArray *comp = [[rule valueForKey:@"parameter"] componentsSeparatedByString:@"/"];
        if ([comp count] != 2)
            return NO;	// corrupted rule
        NSString *host = [comp objectAtIndex:0], *service = [comp objectAtIndex:1];
        
        NSArray *servicesSnapshot = [self.services copy];

        for (NSNetService *aService in servicesSnapshot) {
            if ([[aService name] isEqualToString:host] &&
                [[aService type] isEqualToString:service]) {
                match = YES;
                break;
            }
        }
        //[servicesSnapshot release];

    }
	return match;
}

- (NSString *)getSuggestionLeadText:(NSString *)type {
	return NSLocalizedString(@"The presence of", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions {
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:[self.services count]];
	@synchronized(self) {
        
        for (NSNetService *aService in self.services) {
            NSString *desc = [NSString stringWithFormat:@"%@ on %@", [aService type], [CPBonjourResolver stripLocal:[aService name]]];
            NSString *param = [NSString stringWithFormat:@"%@/%@", [aService name], [aService type]];
            [arr addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                            @"Bonjour", @"type",
                            param, @"parameter",
                            desc, @"description", nil]];
        }
        
    }
    
	return arr;
}

// Triggers stage 1 scanning (probing for what services are available); pass self as arg if this is the initial scan
- (void)considerScanning:(id)arg {
	if (!running)
		return;
    
    [self clearCollectedData];
    
	// This finds all service types
    [self.topLevelNetworkBrowser setDelegate:self];
    [self.topLevelNetworkBrowser setMyServiceType:@"TOP"];
	[self.topLevelNetworkBrowser searchForServicesOfType:@"_services._dns-sd._udp." inDomain:@""];
}


- (void) foundNewServiceFrom:(id)sender withService:(NSNetService *) service {

    // if the sender is our top level network browser then ControlPlane
    // needs to take all of the found services and create new instances
    // of CPBonjourResolver for each one.

    @synchronized(self) {
        NSMutableArray *mutableServicesBeingResolved = [self.servicesBeingResolved mutableCopy];
        if (sender == self.topLevelNetworkBrowser) {
            // if we don't already have an NSNetService object looking for this service we 
            // create one now
            if (![self.servicesByType objectForKey:[NSString stringWithFormat:@"%@.%@", [service name],[CPBonjourResolver stripLocal:[service type]]]]) {
                CPBonjourResolver *tmp = [[CPBonjourResolver alloc] init];
                [tmp setDelegate:self];
                [tmp setMyServiceType:[NSString stringWithFormat:@"%@.%@", [service name],[CPBonjourResolver stripLocal:[service type]]]];
                [tmp searchForServicesOfType:[NSString stringWithFormat:@"%@.%@", [service name],[CPBonjourResolver stripLocal:[service type]]] inDomain:@"local."];
                [self.servicesByType setObject:tmp forKey:[NSString stringWithFormat:@"%@.%@", [service name],[CPBonjourResolver stripLocal:[service type]]]];
                //[tmp release];
            }
        }
        else {
            CPBonjourResolver *tmp = [[CPBonjourResolver alloc] init];
            [tmp setDelegate:self];
            [tmp setMyServiceType:[NSString stringWithFormat:@"%@.%@", [service name],[CPBonjourResolver stripLocal:[service type]]]];
            [tmp doResolveForService:service];
            [mutableServicesBeingResolved addObject:tmp];
            self.servicesBeingResolved = mutableServicesBeingResolved;
            //[tmp release];
        }
    }

}

- (void) resolvedServiceArrived:(id)sender {
    NSMutableArray *toBeAddedTo = [self.services mutableCopy];
    
    @synchronized(self) {
        dataCollected = YES;
    #if DEBUG_MODE
        DSLog(@"adding %@ on %@", [(NSNetService *)sender type], [(NSNetService *) sender name]);
    #endif
        [toBeAddedTo addObject:sender];
    
        self.services = toBeAddedTo;
    }
}

- (void) netServiceBrowser:(id)netServiceBrowser removedService:(NSNetService *)removedService {
    NSMutableArray *toBeDeletedFrom = [self.services mutableCopy];
    @synchronized(self) {
    #if DEBUG_MODE
        DSLog(@"removing %@ on %@", [removedService type], [removedService name]);
    #endif
        [toBeDeletedFrom removeObject:removedService];
        
        self.services = toBeDeletedFrom;
    }
}

- (NSString *) friendlyName {
    return NSLocalizedString(@"Bonjour", @"");
}


@end
