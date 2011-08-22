//
//  LoopingEvidenceSource.h
//  ControlPlane
//
//  Created by David Symonds on 19/07/07.
//

#import <Cocoa/Cocoa.h>
#import "EvidenceSource.h"


@interface LoopingEvidenceSource : EvidenceSource {
	NSTimeInterval loopInterval;
	NSTimer *loopTimer;
}

- (id)initWithNibNamed:(NSString *)name;
- (void)dealloc;

- (void)start;
- (void)stop;

// should be implemented by descendant classes
//- (void)doUpdate;
//- (void)clearCollectedData;

@end
