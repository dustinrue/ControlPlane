//
//  TimeOfDayEvidenceSource.h
//  ControlPlane
//
//  Created by David Symonds on 20/07/07.
//

#import "EvidenceSource.h"


@interface TimeOfDayEvidenceSource : EvidenceSource {
	NSDateFormatter *formatter;

	// For custom panel
	IBOutlet NSArrayController *dayController;
	NSString *selectedDay;
	NSDate *startTime, *endTime;
}

- (id)init;

- (NSMutableDictionary *)readFromPanel;
- (void)writeToPanel:(NSDictionary *)dict usingType:(NSString *)type;

- (void)start;
- (void)stop;

- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;

@end
