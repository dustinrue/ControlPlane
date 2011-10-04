//
//	CallbackSource.h
//	ControlPlane
//
//	Created by David Jennes on 21/09/11.
//	Copyright 2011. All rights reserved.
//

#import "Source.h"

@protocol CallbackSourceProtocol <SourceProtocol>

- (void) registerCallback;
- (void) unregisterCallback;
- (void) checkData;

@end

@interface CallbackSource : Source

- (void) start;
- (void) stop;

@end
