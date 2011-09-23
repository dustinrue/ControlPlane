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
	
	[self registerCallback];
	self.running = YES;
	
	// do a preliminary check
	[self checkData];
}

- (void) stop {
	if (!self.running)
		return;
	
	[self unregisterCallback];
	self.running = NO;
}

#pragma mark - Subclass functions

+ (void) load {
	[self doesNotRecognizeSelector: _cmd];
}

- (NSArray *) observableKeys {
	[self doesNotRecognizeSelector: _cmd];
	return nil;
}

- (void) registerCallback {
	[self doesNotRecognizeSelector: _cmd];
}

- (void) unregisterCallback {
	[self doesNotRecognizeSelector: _cmd];
}

- (void) checkData {
	[self doesNotRecognizeSelector: _cmd];
}

@end
