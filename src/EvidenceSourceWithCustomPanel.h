//
//  EvidenceSourceWithCustomPanel.h
//  MarcoPolo
//
//  Created by David Symonds on 17/07/07.
//

#import <Cocoa/Cocoa.h>
#import "EvidenceSource.h"


@interface EvidenceSourceWithCustomPanel : EvidenceSource {
	NSPanel *panel;
	NSObjectController *objectController;
}

- (id)initWithNibNamed:(NSString *)name;
- (void)dealloc;

@end
