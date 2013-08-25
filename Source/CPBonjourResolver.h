//
//  CPBonjourResolver.h
//  ControlPlane
//
//  Created by Dustin Rue on 3/2/12.
//  Copyright (c) 2012 Dustin Rue. All rights reserved.
//
//  Rework and cleanup done by Vladimir Beloborodov (VladimirTechMan) on 22-23 Aug 2013.
//

#import <Foundation/Foundation.h>


@protocol CPBonjourResolverDelegate <NSObject>;

- (void)foundNewServiceFrom:(id)netServiceBrowser withService:(NSNetService *)service;
- (void)netServiceBrowser:(id)netServiceBrowser removedService:(NSNetService *)removedService;

@end


@interface CPBonjourResolver : NSObject <NSNetServiceBrowserDelegate>

@property (weak) id <CPBonjourResolverDelegate> delegate;

+ (NSString *)stripLocal:(NSString *)incoming;

- (void)searchForServicesOfType:(NSString *)serviceType inDomain:(NSString *)domain;
- (void)stop;

@end
