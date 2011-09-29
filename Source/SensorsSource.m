//
//  LightSource.m
//  ControlPlane
//
//  Created by David Jennes on 29/09/11.
//  Copyright 2011. All rights reserved.
//

#import "SensorsSource.h"
#import <IOKit/graphics/IOGraphicsLib.h>

enum {
	kGetSensorReadingID = 0,	// getSensorReading(int *, int *)
	kGetLEDBrightnessID = 1,	// getLEDBrightness(int, int *)
	kSetLEDBrightnessID = 2		// setLEDBrightness(int, int, int *)
};

@interface SensorsSource (Private)

- (double) getLightLevel;
- (double) getDisplayBrightness;
- (double) getKeyboardBrightness;

@end

@implementation SensorsSource

registerSourceType(SensorsSource)
@synthesize displayBrightness = m_displayBrightness;
@synthesize keyboardBrightness = m_keyboardBrightness;
@synthesize lightLevel = m_lightLevel;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	self.displayBrightness = -1.0;
	self.keyboardBrightness = -1.0;
	self.lightLevel = -1.0;
	self.interval = 2.0;
	m_dataPort = 0;
	
	// Find the IO service
	io_service_t service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleLMUController"));
	ZAssert(service, @"Unable to get Light Controller service");
	
	// Open the IO service
	kern_return_t kr = IOServiceOpen(service, mach_task_self(), 0, &m_dataPort);
	IOObjectRelease(service);
	ZAssert(kr == KERN_SUCCESS, @"Unable to open Light Controller service");
	
	return self;
}

- (void) dealloc {
	IOServiceClose(m_dataPort);
	
	[super dealloc];
}

#pragma mark - Required implementation of 'LoopingSource' class

- (NSArray *) observableKeys {
	return [NSArray arrayWithObjects: @"displayBrightness", @"keyboardBrightness", @"lightLevel", nil];
}

- (void) checkData {
	// Update readings
	self.displayBrightness = [self getDisplayBrightness];
	self.keyboardBrightness = [self getKeyboardBrightness];
	self.lightLevel = [self getLightLevel];
}

#pragma mark - Helper functions

- (double) getLightLevel {
	const double kMaxLightValue = 67092480;
	
	uint32_t size = 2;
	uint64_t data[2] = {0, 0};
	double result = 0.0;
	
	// Read from the sensor device - index 0, 0 inputs, 2 outputs
	kern_return_t kr = IOConnectCallScalarMethod(m_dataPort, kGetSensorReadingID, NULL, 0, data, &size);
	ZAssert(kr == KERN_SUCCESS, @"Unsuccesfully polled light sensor.");
	
	// calc level
	result = (data[0] / kMaxLightValue + data[1] / kMaxLightValue) / 2;
	
	return result;
}

- (double) getDisplayBrightness {
	float brightness = HUGE_VALF;
	io_service_t service = CGDisplayIOServicePort(CGMainDisplayID());

	IODisplayGetFloatParameter(service, kNilOptions, CFSTR(kIODisplayBrightnessKey), &brightness);

	return brightness;
}

- (double) getKeyboardBrightness {
	uint32_t size = 1;
    uint64_t data[1] = {0};
	double result = 0.0;
	
	// Read from the sensor device - index 1, 0 inputs, 1 outputs
	kern_return_t kr = IOConnectCallScalarMethod(m_dataPort, kGetLEDBrightnessID, NULL, 0, data, &size);
	ZAssert(kr == KERN_SUCCESS, @"Unsuccesfully polled keyboard brightness.");
	
	// calc brightness
	result = data[0] / 0xfff;
	
	return result;
}

@end
