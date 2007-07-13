//
//  LightEvidenceSource.m
//  MarcoPolo
//
//  Created by Rodrigo Damazio on 09/07/07.
//

#import <mach/mach.h>
#import <IOKit/IOKitLib.h>
#import "LightEvidenceSource.h"

@implementation LightEvidenceSource

- (id)init
{
	if (!(self = [super init]))
		return nil;

	lock = [[NSLock alloc] init];

	// Initialize suggestions (they're fixed)
	[self initSuggestions];

	// Find the IO service
	kern_return_t kr;
	io_service_t serviceObject = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleLMUController"));  
	if (serviceObject) {
		// Open the IO service
		kr = IOServiceOpen(serviceObject, mach_task_self(), 0, &ioPort);
		IOObjectRelease(serviceObject);
	}

	if (!serviceObject || (kr != KERN_SUCCESS))
		ioPort = nil;

	// We want this to update more regularly than every 10 seconds!
	loopInterval = (NSTimeInterval) 3;

	return self;
}

- (void)dealloc
{
	[suggestions release];
	[lock release];

	[super dealloc];
}

- (void)doUpdate
{
	[lock lock];

	// Read from the sensor device - index 0, 0 inputs, 2 outputs
	kern_return_t kr = IOConnectMethodScalarIScalarO(ioPort, 0, 0, 2, &leftLight, &rightLight);
	[self setDataCollected:(kr == KERN_SUCCESS)];
#ifdef DEBUG_MODE	
	NSLog(@"%@ >> Current light level: L:%d R:%d.\n", [self class], leftLight, rightLight);
#endif

	[lock unlock];
}

- (void)clearCollectedData
{
	[self setDataCollected:NO];
}

- (NSString *)name
{
	return @"Light";
}

- (NSString *)getSuggestionLeadText:(NSString *)type
{
	return NSLocalizedString(@"A light level", @"In rule-adding dialog");
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule
{
	int percentageLevel = [[rule valueForKey:@"parameter"] intValue];

	// FIXME(rdamazio): This value is probably incorrect
	static int kMaxLightValue = 4096;
	[lock lock];
	int currentLevelPercentage = (leftLight + rightLight) * 100 / kMaxLightValue;
	[lock unlock];

	return ((percentageLevel > 0 && currentLevelPercentage > percentageLevel) ||
		    (percentageLevel < 0 && currentLevelPercentage < -percentageLevel));
}

- (NSArray *)getSuggestions
{
	return suggestions;
}

- (void)initSuggestions
{
	if (suggestions)
		return;
	
	static int kLevelPercentages[] = { 10, 25, 50, 75, 90 };
	static int kLevelPercentageCount = 5;

	// In this collection, we use positive numbers to represent "above" and negative ones to represent "below"
	NSMutableArray *levels = [[NSMutableArray arrayWithCapacity:kLevelPercentageCount * 2] retain];
	int i;
	for (i = 0; i < kLevelPercentageCount; ++i) {
		int level = kLevelPercentages[i];

		[levels addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			@"Light", @"type",
			[NSNumber numberWithInt:level], @"parameter",
			[NSString localizedStringWithFormat:@"above %d%%", level], @"description",
			nil]];
	}

	for (i = 0; i < kLevelPercentageCount; ++i) {
		int level = kLevelPercentages[i];

		[levels addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			@"Light", @"type",
			[NSNumber numberWithInt:-level], @"parameter",
			[NSString localizedStringWithFormat:@"below %d%%", level], @"description",
			nil]];
	}

	suggestions = levels;
}

@end
