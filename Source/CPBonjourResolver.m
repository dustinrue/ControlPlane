//
//  CPBonjourResolver.m
//  ControlPlane
//
//  Created by Dustin Rue on 3/2/12.
//  Copyright (c) 2012 Dustin Rue. All rights reserved.
//

#import "CPBonjourResolver.h"
#import "DSLogger.h"

@implementation CPBonjourResolver 

@synthesize delegate;
@synthesize foundItems;
@synthesize myServiceType;

#pragma mark -
#pragma mark init/dealloc
- (id) init {
    self = [super init];
    
    if (!self)
        return self;

    networkBrowser = [[NSNetServiceBrowser alloc] init];
    foundItems = [[NSMutableArray alloc] init];
    
    return self;
}

- (void) dealloc {
    [networkBrowser release];
    [foundItems release];
    [super dealloc];
}


- (void) searchForServicesOfType:(NSString *)serviceType inDomain:(NSString *) searchDomain {
    [networkBrowser setDelegate:self];
    [networkBrowser searchForServicesOfType:serviceType inDomain:searchDomain];
}

- (void) stop {
    [networkBrowser stop];
    [foundItems removeAllObjects];
}

- (void) doResolveForService:(NSNetService *)service {

    [service setDelegate:self];
    [service resolveWithTimeout:2];

}

#pragma mark -
#pragma mark NSNetServiceBrowser and NSNetService delegates
- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser
         didRemoveService:(NSNetService *)netService
               moreComing:(BOOL)moreServicesComing {

    [foundItems removeObject:netService];
    
    if ([[self delegate] respondsToSelector:@selector(netServiceBrowser:removedService:)])
        [[self delegate] netServiceBrowser:self removedService:netService];
    else
        DSLog(@"you're not compliant with CPBonjourResolverDelegate so you missed hearing about this service that went away");
    
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)netServiceBrowser {
#ifdef DEBUG_MODE
	DSLog(@"");
#endif
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser
             didNotSearch:(NSDictionary *)errorInfo {
	DSLog(@"Failed to perform search:\n%@", errorInfo);
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser
           didFindService:(NSNetService *)netService
               moreComing:(BOOL)moreServicesComing {
    
    [foundItems addObject:netService];
    
    if ([[self delegate] respondsToSelector:@selector(foundNewServiceFrom:withService:)]) {
        [[self delegate] foundNewServiceFrom:self withService:netService];
    }
}


- (void)netServiceDidResolveAddress:(NSNetService *)sender {
    if ([[self delegate] respondsToSelector:@selector(resolvedServiceArrived:)])
        [[self delegate] resolvedServiceArrived:sender];
    else
        DSLog(@"you're not compliant with CPBonjourResolverDelegate so you missed on this hot new service I found");
}


- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
        DSLog(@"failed to resolve netService: %@", errorDict);
}


- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindDomain:(NSString *)domainString moreComing:(BOOL)moreComing {
#ifdef DEBUG_MODE
    DSLog(@"");
#endif
}
    



- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveDomain:(NSString *)domainString moreComing:(BOOL)moreComin {
#ifdef DEBUG_MODE
    DSLog(@"");
#endif
}

- (NSUInteger) numberOfHosts {
    return [foundItems count];
}


#pragma mark -
#pragma mark Utility methods
+ (NSString *) stripLocal:(NSString *) incoming {
    if ([incoming hasSuffix:@".local."])
        return[incoming substringToIndex:([incoming length] - 6)];
    
    return incoming;
    
}
@end
