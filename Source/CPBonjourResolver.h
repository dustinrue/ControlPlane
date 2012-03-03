//
//  CPBonjourResolver.h
//  ControlPlane
//
//  Created by Dustin Rue on 3/2/12.
//  Copyright (c) 2012 Dustin Rue. All rights reserved.
//

#import <Foundation/Foundation.h>
@protocol CPBonjourResolverDelegate <NSObject>;

- (void) foundItemsDidChange:(id)sender;
- (void) resolvedServiceArrived:(id)sender;
- (void) serviceRemoved:(NSNetService *)removedService;

@end

@interface CPBonjourResolver : NSObject <NSNetServiceBrowserDelegate, NSNetServiceDelegate> {
    NSNetServiceBrowser *networkBrowser;
    NSMutableArray *foundItems;
    NSMutableArray *resolveQueue;
    NSMutableArray *resolvedItems;
    id delegate;
}

@property (nonatomic, assign) id <CPBonjourResolverDelegate> delegate;
@property (readwrite, assign) NSMutableArray *foundItems;

- (void) searchForServicesOfType:(NSString *)serviceType inDomain:(NSString *) domain;
- (void) stop;
- (void) doResolveForService:(NSNetService *)service;

+ (NSString *) stripLocal:(NSString *) incoming;

@end
