//
//	LoopingSource.h
//	ControlPlane
//
//	Created by David Jennes on 21/09/11.
//	Copyright 2011. All rights reserved.
//

#import "Source.h"

@protocol LoopingSourceProtocol <SourceProtocol>

- (void) checkData;

@end

@interface LoopingSource : Source {
@private
	NSTimeInterval m_interval;
}

@property (readwrite, assign) NSTimeInterval interval;

- (void) start;
- (void) stop;

@end
