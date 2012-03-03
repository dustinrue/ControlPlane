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
    
    networkBrowser = [[NSNetServiceBrowser alloc] init];
    foundItems = [[NSMutableArray alloc] init];
    
    return self;
}

- (void) dealloc {
    [networkBrowser release];
    [super dealloc];
}


- (void) searchForServicesOfType:(NSString *)serviceType inDomain:(NSString *) searchDomain {
    //NSLog(@"new networkBrowser (%@) in search of %@%@", self,serviceType, searchDomain);
    [networkBrowser setDelegate:self];
    [networkBrowser searchForServicesOfType:serviceType inDomain:searchDomain];
}

- (void) stop {
    NSLog(@"stopping %@", self);
    [networkBrowser stop];
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

	NSLog(@"%s service was %@ on %@.", __PRETTY_FUNCTION__, [netService name], [netService hostName]);
    [[self delegate] serviceRemoved:netService];
    
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

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}


- (void)netServiceWillResolve:(NSNetService *)sender {
    //NSLog(@"%s", __PRETTY_FUNCTION__);    
}


- (void)netServiceDidResolveAddress:(NSNetService *)sender {
//    if([[self delegate] respondsToSelector:@selector(foundItemsDidChange:)]) {
//        [[self delegate] foundItemsDidChange:self];
//    }
//        NSLog(@"%s service %@ on %@", __PRETTY_FUNCTION__, [sender type], [sender hostName]);
    [[self delegate] resolvedServiceArrived:sender];
}


- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
        NSLog(@"%s because %@", __PRETTY_FUNCTION__, errorDict);
}

+ (NSString *) stripLocal:(NSString *) incoming {
    if ([incoming hasSuffix:@".local."])
        return[incoming substringToIndex:([incoming length] - 6)];
    
    return incoming;
    
}

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)aNetServiceBrowser {
         //NSLog(@"%s %@", __PRETTY_FUNCTION__, aNetServiceBrowser);   
}



- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindDomain:(NSString *)domainString moreComing:(BOOL)moreComing {
            NSLog(@"%s", __PRETTY_FUNCTION__);
}
    



- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveDomain:(NSString *)domainString moreComing:(BOOL)moreComin {
            NSLog(@"%s", __PRETTY_FUNCTION__);
}



@end
