//
//  CPBonjourResolver.m
//  ControlPlane
//
//  Created by Dustin Rue on 3/2/12.
//  Copyright (c) 2012 Dustin Rue. All rights reserved.
//

#import "CPBonjourResolver.h"

@implementation CPBonjourResolver 

@synthesize delegate;
@synthesize foundItems;

#pragma mark -
#pragma mark init/dealloc
- (id) init {
    self = [super init];
    
    if (!self)
        return self;
    
    NSLog(@"new instance of CPBonjourResolver");
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

    if ([[self delegate] respondsToSelector:@selector(serviceRemoved:)])
        [[self delegate] serviceRemoved:netService];
    else
        NSLog(@"you're not compliant with CPBonjourResolverDelegate so you missed hearing about this service that went away");
    
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)netServiceBrowser {
#ifdef DEBUG_MODE
	NSLog(@"%s called.", __PRETTY_FUNCTION__);
#endif
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser
             didNotSearch:(NSDictionary *)errorInfo {
	NSLog(@"failure:\n%@", errorInfo);
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser
           didFindService:(NSNetService *)netService
               moreComing:(BOOL)moreServicesComing {
    
    [foundItems addObject:netService];
    
    if (!moreServicesComing && [[self delegate] respondsToSelector:@selector(foundItemsDidChange:)]) {
        [[self delegate] foundItemsDidChange:self];
        
    }
}


- (void)netServiceDidResolveAddress:(NSNetService *)sender {
//    if([[self delegate] respondsToSelector:@selector(foundItemsDidChange:)]) {
//        [[self delegate] foundItemsDidChange:self];
//    }
//        NSLog(@"%s service %@ on %@", __PRETTY_FUNCTION__, [sender type], [sender hostName]);
    if ([[self delegate] respondsToSelector:@selector(resolvedServiceArrived:)])
        [[self delegate] resolvedServiceArrived:sender];
    else
        NSLog(@"you're not compliant with CPBonjourResolverDelegate so you missed on this hot new service I found");
}


- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
        NSLog(@"%s because %@", __PRETTY_FUNCTION__, errorDict);
}

+ (NSString *) stripLocal:(NSString *) incoming {
    if ([incoming hasSuffix:@".local."])
        return[incoming substringToIndex:([incoming length] - 6)];
    
    return incoming;
    
}



- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindDomain:(NSString *)domainString moreComing:(BOOL)moreComing {
            NSLog(@"%s", __PRETTY_FUNCTION__);
}
    



- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveDomain:(NSString *)domainString moreComing:(BOOL)moreComin {
            NSLog(@"%s", __PRETTY_FUNCTION__);
}



@end
