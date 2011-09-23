//
//	LoopingSource.h
//	ControlPlane
//
//	Created by David Jennes on 21/09/11.
//	Copyright 2011. All rights reserved.
//

#import "Source.h"

@interface LoopingSource : Source {
@private
	NSTimeInterval m_interval;
}

@property (readwrite, assign) NSTimeInterval interval;

// implemented by subclasses
+ (void) load;
- (NSArray *) observableKeys;
- (void) checkData;

@end
