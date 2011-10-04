//
//	CallbackSource.m
//	ControlPlane
//
//	Created by David Jennes on 21/09/11.
//	Copyright 2011. All rights reserved.
//

#import "CallbackSource.h"

@implementation CallbackSource

- (void) start {
	if (self.running)
		return;
	
	[(id<CallbackSourceProtocol>) self registerCallback];
	self.running = YES;
	
	// do a preliminary check
	[(id<CallbackSourceProtocol>) self checkData];
}

- (void) stop {
	if (!self.running)
		return;
	
	[(id<CallbackSourceProtocol>) self unregisterCallback];
	self.running = NO;
}

@end
