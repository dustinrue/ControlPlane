//
//  BonjourEvidenceSource.m
//  ControlPlane
//
//  Created by David Symonds on 27/08/07.
//  Major rework and cleanup done by Vladimir Beloborodov (VladimirTechMan) on 22-23 Aug 2013.
//
//  IMPORTANT: This code is intended to be compiled for the ARC mode
//

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
#import "CPBonjourResolver.h"

@interface BonjourEvidenceSource () {
    dispatch_queue_t servicesUpdatesSerialQueue;
    dispatch_queue_t browsersUpdatesSerialQueue;
}

// the top level browser responsible for searching all the services in the local domain (see the scheme above)
@property (strong) CPBonjourResolver *topLevelNetworkBrowser;

// service-level browsers by their service type (see the scheme above)
@property (strong) NSMutableDictionary *networkBrowsersByServiceType;

// full resolved services, we now know what service and what host
@property (strong,atomic) NSMutableSet *servicesResolved;

// services to be resolved: when resolved they will be moved into servicesResolved
@property (strong) NSMutableSet *servicesBeingResolved;

@end


#pragma mark -

#define ES_QUEUE_PREFIX "com.dustinrue.ControlPlane.BonjourEvidenceSource"
#define NET_SERVICE_RESOLVE_TIMEOUT_SECS 2

@implementation BonjourEvidenceSource

- (id)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    servicesUpdatesSerialQueue = dispatch_queue_create(ES_QUEUE_PREFIX ".ServicesUpdates", DISPATCH_QUEUE_SERIAL);
    dispatch_set_target_queue(servicesUpdatesSerialQueue, dispatch_get_main_queue());
    
    browsersUpdatesSerialQueue = dispatch_queue_create(ES_QUEUE_PREFIX ".BrowsersUpdates", DISPATCH_QUEUE_SERIAL);
    dispatch_set_target_queue(browsersUpdatesSerialQueue, dispatch_get_main_queue());
    
    if (!servicesUpdatesSerialQueue || !browsersUpdatesSerialQueue) {
        self = nil;
    }
    
	return self;
}

- (void)dealloc {
    if (browsersUpdatesSerialQueue) {
        //dispatch_release(browsersUpdatesSerialQueue);
    }
    if (servicesUpdatesSerialQueue) {
        //dispatch_release(servicesUpdatesSerialQueue);
    }
}

- (NSString *)name {
	return @"Bonjour";
}

- (NSString *)friendlyName {
    return NSLocalizedString(@"Bonjour", @"");
}

- (NSString *)description {
    return NSLocalizedString(@"Create rules based on advertised network services available on your network.", @"");
}

- (void)start {
	if (running) {
		return;
    }

    self.servicesResolved = [[NSMutableSet alloc] init];
    self.servicesBeingResolved = [[NSMutableSet alloc] init];
    self.networkBrowsersByServiceType = [[NSMutableDictionary alloc] init];
    
    CPBonjourResolver *topLevelNetworkBrowser = [[CPBonjourResolver alloc] init];
    self.topLevelNetworkBrowser = topLevelNetworkBrowser;
    topLevelNetworkBrowser.delegate = self;

	// This finds all service types
	[topLevelNetworkBrowser searchForServicesOfType:@"_services._dns-sd._udp." inDomain:@""];
    
    running = YES;
}

- (void)stop {
	if (!running) {
		return;
    }

    [self stopAllBrowsersAndServices];

    self.topLevelNetworkBrowser = nil;
    self.networkBrowsersByServiceType = nil;

    self.servicesBeingResolved = nil;
    self.servicesResolved = nil;

    [self setDataCollected:NO];

	running = NO;
}

- (void)stopAllBrowsersAndServices {
    // stop the on-going request, if any, for the top network browser
    [self.topLevelNetworkBrowser stop];

    // stop on-going requests, if any, for service-level network browsers
    dispatch_suspend(browsersUpdatesSerialQueue);

    [self.networkBrowsersByServiceType enumerateKeysAndObjectsUsingBlock:^(id key, id browser, BOOL *stop) {
        [(CPBonjourResolver *) browser stop];
    }];

    dispatch_resume(browsersUpdatesSerialQueue);

    // stop on-going requests, if any, for net services
    dispatch_suspend(servicesUpdatesSerialQueue);

    [self.servicesBeingResolved enumerateObjectsUsingBlock:^(NSNetService *service, BOOL *stop) {
        [service stop];
    }];

    dispatch_resume(servicesUpdatesSerialQueue);
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule {
    NSArray *comp = [[rule valueForKey:@"parameter"] componentsSeparatedByString:@"/"];
    if ([comp count] != 2) {
        return NO;	// corrupted rule
    }
    
    __block BOOL match = NO;
    NSString *host = comp[0], *service = comp[1];
    
    dispatch_suspend(servicesUpdatesSerialQueue);
    
    NSSet *services = self.servicesResolved;
#ifdef DEBUG_MODE
    DSLog(@"I know about %@", services);
#endif

    [services enumerateObjectsUsingBlock:^(NSNetService *aService, BOOL *stop) {
        *stop = match = ([[aService name] isEqualToString:host] && [[aService type] isEqualToString:service]);
    }];

    dispatch_resume(servicesUpdatesSerialQueue);
    
	return match;
}

- (NSString *)getSuggestionLeadText:(NSString *)type {
	return NSLocalizedString(@"The presence of", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions {
    dispatch_suspend(servicesUpdatesSerialQueue);

    NSSet *services = self.servicesResolved;
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:[services count]];
    for (NSNetService *aService in services) {
        NSString *name = [aService name], *type = [aService type];
        NSString *desc = [NSString stringWithFormat:@"%@ on %@", type, [CPBonjourResolver stripLocal:name]];
        NSString *param = [NSString stringWithFormat:@"%@/%@", name, type];
        [arr addObject:@{ @"type": @"Bonjour", @"parameter": param, @"description": desc }];
    }

    dispatch_resume(servicesUpdatesSerialQueue);

	return arr;
}

#pragma mark -
#pragma mark CPBonjourResolver delegates

- (void)foundNewServiceFrom:(id)netServiceBrowser withService:(NSNetService *)service {
    // if the sender is our top level network browser then ControlPlane
    // needs to take all of the found services and create new instances
    // of CPBonjourResolver for each one.
    if (netServiceBrowser == self.topLevelNetworkBrowser) {
        NSString *serviceType = [NSString stringWithFormat:@"%@.%@", [service name],
                                 [CPBonjourResolver stripLocal:[service type]]];
        dispatch_async(browsersUpdatesSerialQueue, ^{
            // if we don't already have an NSNetService object looking for this service we
            // create one now
            NSMutableDictionary *networkBrowsers = self.networkBrowsersByServiceType;
            if (!networkBrowsers[serviceType]) {
                CPBonjourResolver *resolver = [[CPBonjourResolver alloc] init];
                networkBrowsers[serviceType] = resolver;

                resolver.delegate = self;
                [resolver searchForServicesOfType:serviceType inDomain:@"local."];
            }
        });

        return;
    }

    // resolve the new service
    dispatch_async(servicesUpdatesSerialQueue, ^{
        [self.servicesBeingResolved addObject:service];
        [service setDelegate:self];
        [service scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [service resolveWithTimeout:NET_SERVICE_RESOLVE_TIMEOUT_SECS];
    });
}

- (void)netServiceBrowser:(id)netServiceBrowser removedService:(NSNetService *)removedService {
    dispatch_async(servicesUpdatesSerialQueue, ^{
#if DEBUG_MODE
        DSLog(@"Removing %@ on %@", [removedService type], [removedService name]);
#endif

        // in case if the service is not resolved yet
        [removedService stop];
        [self.servicesBeingResolved removeObject:removedService];

        NSMutableSet *servicesResolved = self.servicesResolved;
        [servicesResolved removeObject:removedService];
        if ([servicesResolved count] == 0) {
            [self setDataCollected:NO];
        }
    });
}

#pragma mark -
#pragma mark NSNetService delegates

- (void)netServiceDidResolveAddress:(NSNetService *)resolvedService {
    dispatch_async(servicesUpdatesSerialQueue, ^{
#if DEBUG_MODE
        DSLog(@"Adding %@ on %@", [resolvedService type], [resolvedService name]);
#endif
        
        [self.servicesBeingResolved removeObject:resolvedService];
        [self.servicesResolved addObject:resolvedService];
        [self setDataCollected:YES];
    });
}

- (void)netService:(NSNetService *)service didNotResolve:(NSDictionary *)errorDict {
    [self.servicesBeingResolved removeObject:service];

    switch ([errorDict[NSNetServicesErrorCode] intValue]) {
        case NSNetServicesTimeoutError:
            DSLog(@"Failed to resolve net service '%@' within %d seconds",
                    [service name], NET_SERVICE_RESOLVE_TIMEOUT_SECS);
            break;
            
        default:
            DSLog(@"Failed to resolve net service '%@':\n%@", [service name], errorDict);
            break;
    }
}

@end
