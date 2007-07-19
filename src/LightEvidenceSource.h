//
//  LightEvidenceSource.h
//  MarcoPolo
//
//  Created by Rodrigo Damazio on 09/07/07.
//

#import <Cocoa/Cocoa.h>
#import <IOKit/IOTypes.h>
#import "LoopingEvidenceSource.h"

@interface LightEvidenceSource : LoopingEvidenceSource {
	NSLock *lock;
	io_connect_t ioPort;
	int leftLight, rightLight;

	// For custom panel
	NSNumber *threshold;		// double: [0.0, 1.0]
	NSNumber *aboveThreshold;	// bool
}

- (id)init;
- (void)dealloc;

- (void)doUpdate;
- (void)clearCollectedData;

- (NSMutableDictionary *)readFromPanel;
- (void)writeToPanel:(NSDictionary *)dict usingType:(NSString *)type;

- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;

@end
