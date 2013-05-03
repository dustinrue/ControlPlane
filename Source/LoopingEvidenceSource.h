//
//  LoopingEvidenceSource.h
//  ControlPlane
//
//  Created by David Symonds on 19/07/07.
//

#import "EvidenceSource.h"


@interface LoopingEvidenceSource : EvidenceSource {
	NSTimeInterval loopInterval;
}

- (id)initWithNibNamed:(NSString *)name;
- (void)dealloc;

- (void)start;
- (void)stop;

// should be implemented by descendant classes
//- (void)doUpdate;
//- (void)clearCollectedData;

@end
