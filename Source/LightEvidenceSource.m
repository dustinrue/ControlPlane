//
//  LightEvidenceSource.m
//  ControlPlane
//
//  Created by Rodrigo Damazio on 09/07/07.
//

#import <mach/mach.h>
#import <IOKit/IOKitLib.h>
#import "LightEvidenceSource.h"




@interface LightEvidenceSource (Private)

- (double)levelFromRawLeft:(uint64_t)left andRight:(uint64_t)right;

@end

#pragma mark -

@implementation LightEvidenceSource

// Returns value in [0.0, 1.0]
- (double)levelFromRawLeft:(uint64_t)left andRight:(uint64_t)right
{
	// FIXME(rdamazio): This value is probably incorrect
	// COMMENTS(dustinrue) below is the observed max value on a 13" unibody MacBook (Late 2008)
	// This value is ridiculous and results in a much smaller
	// useful value range.  
	static double kMaxLightValue = 67092480; 
										
	
	// determine average value from the two sensors	
	return (left/kMaxLightValue + right/kMaxLightValue) / 2;
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
		ioPort = 0;

	// We want this to update more regularly than every 10 seconds!
	loopInterval = (NSTimeInterval) 1.5;

	return self;
}

- (void)dealloc
{
	[lock release];

	[super dealloc];
}


- (NSString *) description {
    return NSLocalizedString(@"Create rules based on the amount of ambient light if your Mac is equipped with ambient light sensors.", @"");
}

- (void)doUpdate
{
	[lock lock];
	kern_return_t kr;
	uint32_t	outputCnt = 2;
	uint64_t    scalarI_64[2];
	scalarI_64[0] = 0;
	scalarI_64[1] = 0;

	// Read from the sensor device - index 0, 0 inputs, 2 outputs
	kr = IOConnectCallScalarMethod(ioPort, kGetSensorReadingID, NULL, 0, scalarI_64, &outputCnt);
		
	leftLight  = scalarI_64[0];
	rightLight = scalarI_64[1];
	if (kr == KERN_SUCCESS) {  
#ifdef DEBUG_MODE
		NSLog(@"%@ >> successfully polled light sensor using 10.5+ method", [self class]);
#endif
	}
	else {
#ifdef DEBUG_MODE
		NSLog(@"%@ >> unsuccessfully polled light sensor using 10.5+ method", [self class]);
#endif
		mach_error("I/O Kit error, this computer doesn't have light sensors and you should disable the light evidence source:", kr); 
	}    

	//kern_return_t kr = IOConnectMethodScalarIScalarO(ioPort, 0, 0, 2, &leftLight, &rightLight);
	[self setDataCollected:(kr == KERN_SUCCESS)];

	// Update bindable key
	NSNumberFormatter *nf = [[[NSNumberFormatter alloc] init] autorelease];
	[nf setFormatterBehavior:NSNumberFormatterBehavior10_4];
	[nf setNumberStyle:NSNumberFormatterPercentStyle];
	NSNumber *level = [NSNumber numberWithDouble:[self levelFromRawLeft:leftLight andRight:rightLight]];
	NSString *perc = [nf stringFromNumber:level];
	[self setValue:perc forKey:@"currentLevel"];

#ifdef DEBUG_MODE
	NSLog(@"%@ >> Current light level: L:%llu R:%llu. (%@)", [self class], leftLight, rightLight, currentLevel);
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
		level = [[dict valueForKey:@"parameter"] doubleValue];
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

- (NSString *) friendlyName {
    return NSLocalizedString(@"Light Sensor", @"");
}

@end
