//
//  LightEvidenceSource.h
//  ControlPlane
//
//  Created by Rodrigo Damazio on 09/07/07.
//  Some optimizations and refactoring by Vladimir Beloborodov (VladimirTechMan) on 05 August 2013.
//

#import "LoopingEvidenceSource.h"

enum {  
	kGetSensorReadingID = 0,
	kGetLEDBrightnessID = 1, 
	kSetLEDBrightnessID = 2,
	kSetLEDFadeID = 3,  
}; 

@interface LightEvidenceSource : LoopingEvidenceSource

- (id)init;
- (void)dealloc;

- (void)doUpdate;
- (void)clearCollectedData;

- (NSMutableDictionary *)readFromPanel;
- (void)writeToPanel:(NSDictionary *)dict usingType:(NSString *)type;

- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;

@end
