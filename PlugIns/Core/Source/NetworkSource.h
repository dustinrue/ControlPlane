//
//  NetworkSource.h
//  ControlPlane
//
//  Created by David Jennes on 04/10/11.
//  Copyright 2011. All rights reserved.
//

#import "CallbackSource.h"
#import <SystemConfiguration/SCDynamicStore.h>

@interface NetworkSource : CallbackSource<CallbackSourceProtocol> {
	NSArray *m_addresses;
	NSDictionary *m_interfaces;
	NSDictionary *m_interfaceNames;
	
	SCDynamicStoreRef m_store;
	CFRunLoopSourceRef m_runLoop;
}

@property (readwrite, copy) NSArray *addresses;
@property (readwrite, copy) NSDictionary *interfaces;
@property (readwrite, copy) NSDictionary *interfaceNames;

@end
