//
//	BonjourSource.m
//	ControlPlane
//
//	Created by David Jennes on 21/09/11.
//	Copyright 2011. All rights reserved.
//

#import "BonjourSource.h"
#import "KVOAdditions.h"
#import "Rule.h"
#import "SourcesManager.h"

@interface BonjourSource (Private)

- (void) startScanning;
- (void) startResolving;
- (void) resolveNextService;

@end

@implementation BonjourSource

@synthesize services = m_services;

- (id) init {
	self = [super init];
	if (!self)
		return nil;
	
	m_stage = kNetNothing;
	m_timer = nil;
	m_browser = [[NSNetServiceBrowser alloc] init];
	m_unresolvedServices = [[NSMutableArray alloc] init];
	m_resolvedServices = [[NSMutableArray alloc] init];
	[m_browser setDelegate: self];
	
	self.services = [[[NSArray alloc] init] autorelease];
	
	return self;
}

- (void) dealloc {
	[m_browser release];
	[m_unresolvedServices release];
	[m_resolvedServices release];
	
	[super dealloc];
}

#pragma mark - Required implementation of 'Source' class

+ (void) load {
	[[SourcesManager sharedSourcesManager] registerSourceType: self];
}

- (void) addObserver: (Rule *) rule {
	SEL selector = NSSelectorFromString(@"servicesChangedWithOld:andNew:");
	
	[self addObserver: rule
		   forKeyPath: @"services"
			  options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
			 selector: selector];
}

- (void) removeObserver: (Rule *) rule {
	[self removeObserver: rule forKeyPath: @"services" selector: nil];
}

- (void) checkData {
	switch (m_stage) {
		case kNetNothing:
			// start a scan
			[self startScanning];
			break;
		case kNetFinished:
			// store scan results
			self.services = m_resolvedServices;
			m_stage = kNetNothing;
			break;
		default:
			break;
	}
}

#pragma mark - Scan control functions

- (void) startScanning {
	m_stage = kNetScanning;
	[m_unresolvedServices removeAllObjects];
	[m_resolvedServices removeAllObjects];
	
	// This finds all service types
	[m_browser searchForServicesOfType: @"_services._dns-sd._udp." inDomain: @""];
}

- (void) startResolving {
	m_stage = kNetResolving;
	[self resolveNextService];
}

- (void) resolveNextService {
	[m_browser stop];
	m_timer = nil;
	
	// check if anything left to do
	if ([m_unresolvedServices count] == 0) {
		m_stage = kNetFinished;
		return;
	}
	
	// resolve first in list
	NSString *service = [m_unresolvedServices objectAtIndex: 0];
	[m_browser searchForServicesOfType: service inDomain: @""];
	[m_unresolvedServices removeObjectAtIndex: 0];
	
	// if resolving takes too long, resolve next one
	m_timer = [NSTimer scheduledTimerWithTimeInterval: 1
											   target: self
											 selector: @selector(resolveNextService)
											 userInfo: nil
											  repeats: NO];
}

#pragma mark - NetServiceBrowser delegate functions

- (void) netServiceBrowser: (NSNetServiceBrowser *) netServiceBrowser
			didFindService: (NSNetService *) netService
				moreComing: (BOOL) moreServicesComing {
	
	NSString *service;
	NSDictionary *hit;
	
	// depending on stage, add to correct array
	switch (m_stage) {
		case kNetScanning:
			service = [NSString stringWithFormat: @"%@.%@", [netService name], [netService type]];
			if ([service hasSuffix: @".local."])
				service = [service substringToIndex: ([service length] - 6)];
			
			[m_unresolvedServices addObject: service];
			break;
		case kNetResolving:
			hit = [NSDictionary dictionaryWithObjectsAndKeys:
				   [netService name], @"host",
				   [netService type], @"service",
				   nil];
			
			[m_resolvedServices addObject: hit];
			break;
		default:
			break;
	}
	
	if (moreServicesComing)
		return;
	
	// we found everything, onto next stage if needed
	[netServiceBrowser stop];
	if (m_stage == kNetScanning)
		m_stage = kNetResolving;
	
	// resolve next
	if (m_timer) {
		[m_timer invalidate];
		[m_timer release];
	}
	[self resolveNextService];
}

- (void) netServiceBrowser: (NSNetServiceBrowser *) netServiceBrowser
			  didNotSearch: (NSDictionary *) errorInfo {
	DLog(@"failure:\n%@", errorInfo);
}

@end
