//
//  LightEvidenceSource.h
//  ControlPlane
//
//  Created by Rodrigo Damazio on 09/07/07.
//

#import <Cocoa/Cocoa.h>
#import <IOKit/IOTypes.h>
#import "LoopingEvidenceSource.h"

enum {  
	kGetSensorReadingID = 0,
	kGetLEDBrightnessID = 1, 
	kSetLEDBrightnessID = 2,
	kSetLEDFadeID = 3,  
}; 



@interface LightEvidenceSource : LoopingEvidenceSource {
	NSLock *lock;
	io_connect_t ioPort;
	int leftLight, rightLight;
	int maxLevel;

	// For custom panel
	NSString *currentLevel;		// bindable (e.g. "67%")
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
