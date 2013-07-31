//
//  GenericLoopingEvidenceSource.h
//  ControlPlane
//
//  Created by David Symonds on 19/07/07.
//  Updated by Vladimir Beloborodov (VladimirTechMan) on 03 May 2013.
//

#import "GenericEvidenceSource.h"


@interface GenericLoopingEvidenceSource : GenericEvidenceSource {
	NSTimeInterval loopInterval;
    NSTimeInterval loopLeeway;
}

- (id)init;	// can be extended by descendant classes to change loopInterval
- (void)dealloc;

- (void)start;
- (void)stop;

// should be implemented by descendant classes
//- (void)doUpdate;
//- (void)clearCollectedData;

@end
