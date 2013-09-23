//
//  CPBonjourResolver.m
//  ControlPlane
//
//  Created by Dustin Rue on 3/2/12.
//  Copyright (c) 2012 Dustin Rue. All rights reserved.
//
//  Rework and cleanup done by Vladimir Beloborodov (VladimirTechMan) on 22-23 Aug 2013.
//
//  IMPORTANT: This code is intended to be compiled for the ARC mode
//

#import "CPBonjourResolver.h"
#import "DSLogger.h"


@implementation CPBonjourResolver {
    NSNetServiceBrowser *networkBrowser;
}

#pragma mark -
#pragma mark init/dealloc
- (id)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    networkBrowser = [[NSNetServiceBrowser alloc] init];
    [networkBrowser scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    
    return self;
}

- (void)dealloc {
}

- (void)searchForServicesOfType:(NSString *)serviceType inDomain:(NSString *)searchDomain {
    networkBrowser.delegate = self;
    [networkBrowser searchForServicesOfType:serviceType inDomain:searchDomain];
}

- (void)stop {
    [networkBrowser stop];
}

#pragma mark -
#pragma mark NSNetServiceBrowser delegates
- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser
         didRemoveService:(NSNetService * __autoreleasing)netService
               moreComing:(BOOL)moreServicesComing {
    id <CPBonjourResolverDelegate> delegate = self.delegate;
    if (!delegate) {
        return;
    }
    
    if (![delegate respondsToSelector:@selector(netServiceBrowser:removedService:)]) {
        DSLog(@"Delegate is not compliant with CPBonjourResolverDelegate"
              " so you missed hearing about a service that went away");
        return;
    }
    
    [delegate netServiceBrowser:self removedService:netService];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser
           didFindService:(NSNetService * __autoreleasing)netService
               moreComing:(BOOL)moreServicesComing {
    id <CPBonjourResolverDelegate> delegate = self.delegate;
    if (!delegate) {
        return;
    }
    
    if (![delegate respondsToSelector:@selector(foundNewServiceFrom:withService:)]) {
        DSLog(@"Delegate is not compliant with CPBonjourResolverDelegate"
              " so you missed hearing about a service that is available");
        return;
    }
    
    [delegate foundNewServiceFrom:self withService:netService];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser
             didNotSearch:(NSDictionary *)errorInfo {
	DSLog(@"Failed to perform search:\n%@", errorInfo);
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)netServiceBrowser {
#ifdef DEBUG_MODE
	DSLog(@"");
#endif
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser
            didFindDomain:(NSString *)domainString
               moreComing:(BOOL)moreComing {
#ifdef DEBUG_MODE
    DSLog(@"");
#endif
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser
          didRemoveDomain:(NSString *)domainString
               moreComing:(BOOL)moreComin {
#ifdef DEBUG_MODE
    DSLog(@"");
#endif
}

#pragma mark -
#pragma mark Utility methods
+ (NSString *)stripLocal:(NSString *)incoming {
    if ([incoming hasSuffix:@".local."]) {
        return [incoming substringToIndex:([incoming length] - 6)];
    }
    return incoming;
}

@end
