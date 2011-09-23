//
//	LoopingSource.h
//	ControlPlane
//
//	Created by David Jennes on 21/09/11.
//	Copyright 2011. All rights reserved.
//

#import "Source.h"

@interface LoopingSource : Source {
	@protected NSTimeInterval m_interval;
}

@property (readwrite, assign) NSTimeInterval interval;

// implemented by subclasses
+ (void) load;
- (void) addObserver: (Rule *) rule;
- (void) removeObserver: (Rule *) rule;
- (void) checkData;

@end
