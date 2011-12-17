//
//  NSTimer+Invalidation.h
//  ControlPlane
//
//  Created by David Jennes on 17/12/11.
//  Copyright (c) 2011. All rights reserved.
//

@interface NSTimer (Invalidation)

/**
 * Provide a safe way to invalidate a retained timer. This will:
 * - invalidate if still valid
 * - call release
 * - return nil (for convenience)
 */
- (id) checkAndInvalidate;

@end
