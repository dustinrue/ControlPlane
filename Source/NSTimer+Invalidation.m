//
//  NSTimer+Invalidation.m
//  ControlPlane
//
//  Created by David Jennes on 17/12/11.
//  Copyright (c) 2011. All rights reserved.
//

#import "NSTimer+Invalidation.h"

@implementation NSTimer (Invalidation)

- (id) checkAndInvalidate {
	if (self.isValid)
		[self invalidate];
	
	[self release];
	return nil;
}

@end
