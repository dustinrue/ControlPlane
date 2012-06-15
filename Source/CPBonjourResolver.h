//
//  CPBonjourResolver.h
//  ControlPlane
//
//  Created by Dustin Rue on 3/2/12.
//  Copyright (c) 2012 Dustin Rue. All rights reserved.
//

#import <Foundation/Foundation.h>
@protocol CPBonjourResolverDelegate <NSObject>;

- (void) foundNewServiceFrom:(id)sender withService:(NSNetService *) service;
- (void) resolvedServiceArrived:(id)sender;
- (void) netServiceBrowser:(id)netServiceBrowser removedService:(NSNetService *)removedService;

@end




@interface CPBonjourResolver : NSObject <NSNetServiceBrowserDelegate, NSNetServiceDelegate> {
    NSNetServiceBrowser *networkBrowser;
    NSMutableArray *foundItems;
    NSMutableArray *resolveQueue;
    NSMutableArray *resolvedItems;
    
    NSString * myServiceType;
    id delegate;
}

@property (nonatomic, assign) id <CPBonjourResolverDelegate> delegate;
@property (readwrite, assign) NSMutableArray *foundItems;
@property (readwrite, retain) NSString *myServiceType;

- (void) searchForServicesOfType:(NSString *)serviceType inDomain:(NSString *) domain;
- (void) stop;
- (void) doResolveForService:(NSNetService *)service;
- (NSUInteger) numberOfHosts;

+ (NSString *) stripLocal:(NSString *) incoming;

@end
