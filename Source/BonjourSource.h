//
//	BonjourSource.h
//	ControlPlane
//
//	Created by David Jennes on 21/09/11.
//	Copyright 2011. All rights reserved.
//

#import "LoopingSource.h"

typedef enum {
	kNetNothing,
	kNetScanning,
	kNetResolving,
	kNetFinished
} NetStage;

@interface BonjourSource : LoopingSource<NSNetServiceBrowserDelegate> {
	NSNetServiceBrowser *m_browser;
	NSMutableArray *m_unresolvedServices;
	NSMutableArray *m_resolvedServices;
	NSArray *m_services;
	NSTimer *m_timer;
	NetStage m_stage;
}

@property (readwrite, copy) NSArray *services;

@end
