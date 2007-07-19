//
//  LightEvidenceSource.m
//  MarcoPolo
//
//  Created by Rodrigo Damazio on 09/07/07.
//

#import <mach/mach.h>
#import <IOKit/IOKitLib.h>
#import "LightEvidenceSource.h"


@interface LightEvidenceSource (Private)

- (double)levelFromRawLeft:(int)left andRight:(int)right;

@end

#pragma mark -

@implementation LightEvidenceSource

// Returns value in [0.0, 1.0]
- (double)levelFromRawLeft:(int)left andRight:(int)right
{
	// FIXME(rdamazio): This value is probably incorrect
	static double kMaxLightValue = 4096.0;
	return (left + right) / kMaxLightValue;
}

- (id)init
{
	if (!(self = [super initWithNibNamed:@"LightRule"]))
		return nil;

	lock = [[NSLock alloc] init];

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
	loopInterval = (NSTimeInterval) 1.5;

	return self;
}

- (void)dealloc
{
	[lock release];

	[super dealloc];
}

- (void)doUpdate
{
	[lock lock];

	// Read from the sensor device - index 0, 0 inputs, 2 outputs
	kern_return_t kr = IOConnectMethodScalarIScalarO(ioPort, 0, 0, 2, &leftLight, &rightLight);
	[self setDataCollected:(kr == KERN_SUCCESS)];

	// Update bindable key
	NSNumberFormatter *nf = [[[NSNumberFormatter alloc] init] autorelease];
	[nf setFormatterBehavior:NSNumberFormatterBehavior10_4];
	[nf setNumberStyle:NSNumberFormatterPercentStyle];
	NSNumber *level = [NSNumber numberWithDouble:[self levelFromRawLeft:leftLight andRight:rightLight]];
	NSString *perc = [nf stringFromNumber:level];
	[self setValue:perc forKey:@"currentLevel"];

#ifdef DEBUG_MODE	
	NSLog(@"%@ >> Current light level: L:%d R:%d. (%@)\n", [self class], leftLight, rightLight, currentLevel);
#endif
	[lock unlock];
}

- (void)clearCollectedData
{
	[self setDataCollected:NO];
}

- (NSMutableDictionary *)readFromPanel
{
	NSMutableDictionary *dict = [super readFromPanel];

	double level = [threshold doubleValue];
	NSNumber *param;
	if ([aboveThreshold boolValue])
		param = [NSNumber numberWithDouble:level];
	else
		param = [NSNumber numberWithDouble:-level];

	NSString *desc;
	NSNumberFormatter *nf = [[[NSNumberFormatter alloc] init] autorelease];
	[nf setFormatterBehavior:NSNumberFormatterBehavior10_4];
	[nf setNumberStyle:NSNumberFormatterPercentStyle];
	NSString *perc = [nf stringFromNumber:[NSDecimalNumber numberWithDouble:level]];	
	if ([aboveThreshold boolValue])
		desc = [NSString stringWithFormat:NSLocalizedString(@"Above %@", @"Parameter is a percentage threshold"), perc];
	else
		desc = [NSString stringWithFormat:NSLocalizedString(@"Below %@", @"Parameter is a percentage threshold"), perc];

	[dict setValue:param forKey:@"parameter"];
	if (![dict objectForKey:@"description"])
		[dict setValue:desc forKey:@"description"];

	return dict;
}

- (void)writeToPanel:(NSDictionary *)dict usingType:(NSString *)type
{
	[super writeToPanel:dict usingType:type];

	BOOL above = YES;
	double level = 0.5;
	if ([dict objectForKey:@"parameter"]) {
		double level = [[dict valueForKey:@"parameter"] doubleValue];
		above = (level >= 0);
		level = fabs(level);
	}

	[self setValue:[NSNumber numberWithBool:above] forKey:@"aboveThreshold"];
	[self setValue:[NSNumber numberWithDouble:level] forKey:@"threshold"];
}

- (NSString *)name
{
	return @"Light";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule
{
	double level = [[rule valueForKey:@"parameter"] doubleValue];

	[lock lock];
	double nowLevel = [self levelFromRawLeft:leftLight andRight:rightLight];
	[lock unlock];

	return ((level > 0 && nowLevel > level) || (level < 0 && nowLevel < -level));
}

@end
