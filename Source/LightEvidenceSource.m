//
//  LightEvidenceSource.m
//  ControlPlane
//
//  Created by Rodrigo Damazio on 09/07/07.
//  Some optimizations and refactoring by Vladimir Beloborodov (VladimirTechMan) on 05 August 2013.
//

#import <mach/mach.h>
#import <IOKit/IOKitLib.h>
#import "LightEvidenceSource.h"
#import "SharedNumberFormatter.h"


enum {
	kGetSensorReadingID = 0,
	kGetLEDBrightnessID = 1,
	kSetLEDBrightnessID = 2,
	kSetLEDFadeID = 3,
};


@interface LightEvidenceSource () {
	io_connect_t ioPort;
	int maxLevel;
    
	// For custom panel
	NSString *currentLevel;		// bindable (e.g. "67%")
	NSNumber *threshold;		// double: [0.0, 1.0]
	NSNumber *aboveThreshold;	// bool
}

@property (atomic,assign,readwrite) double level;

@end

#pragma mark -

@implementation LightEvidenceSource

- (id)init {
	if (!(self = [super initWithNibNamed:@"LightRule"])) {
		return nil;
    }

    [self openAppleLMUController];

	// We want this to update more regularly than every 10 seconds!
	loopInterval = (NSTimeInterval) 1.5;

    currentLevel = @"N/A"; // Signal error if not getting updated
    
    return self;
}

- (void)dealloc {
	[super dealloc];
}

- (BOOL)openAppleLMUController {
    // Find the IO service
    kern_return_t kr = KERN_FAILURE;
    io_service_t serviceObject = IOServiceGetMatchingService(kIOMasterPortDefault,
                                                             IOServiceMatching("AppleLMUController"));
    if (serviceObject) {
        // Open the IO service
        kr = IOServiceOpen(serviceObject, mach_task_self(), 0, &ioPort);
        IOObjectRelease(serviceObject);
    }

    if (!serviceObject || (kr != KERN_SUCCESS)) {
        ioPort = 0;
    }
    
    return (kr == KERN_SUCCESS);
}

- (NSString *)description {
    return NSLocalizedString(@"Create rules based on the amount of ambient light "
                             "if your Mac is equipped with ambient light sensors.", @"");
}

// Returns value in [0.0, 1.0]
- (double)levelFromRawLeft:(uint64_t)left andRight:(uint64_t)right {
	// FIXME(rdamazio): This value is probably incorrect
	// COMMENTS(dustinrue) below is the observed max value on a 13" unibody MacBook (Late 2008)
	// This value is ridiculous and results in a much smaller
	// useful value range.
	const double kMaxLightValue = 67092480.0;

    const double avg = (left + right) / 2; // determine average value from the two sensors
	return (avg / kMaxLightValue); // normalize
}

- (void)doUpdate {
	uint64_t scalarI_64[] = { 0, 0 };
	uint32_t outputCnt = 2;

	// Read from the sensor device - index 0, 0 inputs, 2 outputs
	kern_return_t kr = IOConnectCallScalarMethod(ioPort, kGetSensorReadingID, NULL, 0, scalarI_64, &outputCnt);
	double level = [self levelFromRawLeft:scalarI_64[0] andRight:scalarI_64[1]];

#ifdef DEBUG_MODE
    if (kr == KERN_SUCCESS) {
        NSLog(@"%@ >> Current light level: L:%llu R:%llu. (%@)", [self class], scalarI_64[0], scalarI_64[1], currentLevel);
	} else
#endif
    {
#ifdef DEBUG_MODE
		NSLog(@"%@ >> unsuccessfully polled light sensor using 10.5+ method", [self class]);
#endif
		mach_error("I/O Kit error, this computer doesn't have light sensors "
                   "and you should disable the light evidence source:", kr);
	}    

    if (self.level != level) {
        self.level  = level;
        [self setDataCollected:(kr == KERN_SUCCESS)];

        NSString *perc = [[SharedNumberFormatter percentStyleFormatter] stringFromNumber:@(level)];
        [self setValue:perc forKey:@"currentLevel"];
    }
}

- (void)clearCollectedData {
	[self setDataCollected:NO];
}

- (NSMutableDictionary *)readFromPanel {
	NSMutableDictionary *dict = [super readFromPanel];

	double level = [threshold doubleValue];
	dict[@"parameter"] = ([aboveThreshold boolValue]) ? @(level) : @(-level);

	if (![dict objectForKey:@"description"]) {
        NSString *fmt;
        if ([aboveThreshold boolValue]) {
            fmt = NSLocalizedString(@"Above %@", @"Parameter is a percentage threshold");
        } else {
            fmt = NSLocalizedString(@"Below %@", @"Parameter is a percentage threshold");
        }
        NSString *perc = [[SharedNumberFormatter percentStyleFormatter] stringFromNumber:@(level)];
        NSString *desc = [NSString stringWithFormat:fmt, perc];
		dict[@"description"] = desc;
    }

	return dict;
}

- (void)writeToPanel:(NSDictionary *)dict usingType:(NSString *)type {
	[super writeToPanel:dict usingType:type];

	BOOL above = YES;
	double level = 0.5;
	if ([dict objectForKey:@"parameter"]) {
		level = [dict[@"parameter"] doubleValue];
		above = (level >= 0);
		level = fabs(level);
	}

	[self setValue:[NSNumber numberWithBool:above] forKey:@"aboveThreshold"];
	[self setValue:[NSNumber numberWithDouble:level] forKey:@"threshold"];
}

- (NSString *)name {
	return @"Light";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule {
	double rulelevel = [rule[@"parameter"] doubleValue];
    double nowLevel = self.level;
	return ((rulelevel > 0 && nowLevel > rulelevel) || (rulelevel < 0 && nowLevel < -rulelevel));
}

- (NSString *) friendlyName {
    return NSLocalizedString(@"Light Sensor", @"");
}

+ (BOOL) isEvidenceSourceApplicableToSystem {
    LightEvidenceSource *les = [[LightEvidenceSource alloc] init];
    BOOL test = [les openAppleLMUController];
    [les release];
    
    return test;
}

@end
