//
//  TimeOfDayEvidenceSource.h
//  MarcoPolo
//
//  Created by David Symonds on 20/07/07.
//

#import <Cocoa/Cocoa.h>
#import "EvidenceSource.h"


@interface TimeOfDayEvidenceSource : EvidenceSource {
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
