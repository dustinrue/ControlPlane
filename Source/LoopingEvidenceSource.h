//
//  LoopingEvidenceSource.h
//  ControlPlane
//
//  Created by David Symonds on 19/07/07.
//  Updated by Vladimir Beloborodov (VladimirTechMan) on 03 May 2013.
//

#import "EvidenceSource.h"


@interface LoopingEvidenceSource : EvidenceSource {
	NSTimeInterval loopInterval;
    NSTimeInterval loopLeeway;
}

- (id)initWithNibNamed:(NSString *)name;
- (void)dealloc;

- (void)start;
- (void)stop;

// should be implemented by descendant classes
//- (void)doUpdate;
//- (void)clearCollectedData;

@end
