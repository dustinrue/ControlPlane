//
//	DisplayBrightnessAction.m
//	ControlPlane
//
//	Created by David Jennes on 02/09/11.
//	Copyright 2011. All rights reserved.
//

#import "DisplayBrightnessAction.h"
#import "DSLogger.h"
#include <IOKit/graphics/IOGraphicsLib.h>

@interface DisplayBrightnessAction (Private)

+ (void) setBrightness: (float) brightness;

@end

@implementation DisplayBrightnessAction

- (id) init {
	self = [super init];
	if (!self)
		return nil;
	
	brightnessText = [[NSString alloc] init];
	brightness = 100;
	
	return self;
}

- (id) initWithDictionary: (NSDictionary *) dict {
	self = [super initWithDictionary: dict];
	if (!self)
		return nil;
	
	brightnessText = [[dict valueForKey: @"parameter"] copy];
	brightness = (unsigned int) [brightnessText intValue];
	
	// must be between 0 and 100
	brightness = (brightness > 100) ? 100 : brightness;
	brightnessText = [[NSString stringWithFormat: @"%d", brightness] copy];
	
	return self;
}

- (void) dealloc {
	[brightnessText release];
	
	[super dealloc];
}

- (NSMutableDictionary *) dictionary {
	NSMutableDictionary *dict = [super dictionary];
	
	[dict setObject: [[brightnessText copy] autorelease] forKey: @"parameter"];
	
	return dict;
}

- (NSString *) description {
	return [NSString stringWithFormat: NSLocalizedString(@"Set brightness to %@%%.", @""), brightnessText];
}

- (BOOL) execute: (NSString **) errorString {
	const int kMaxDisplays = 16;
	const CFStringRef kDisplayBrightness = CFSTR(kIODisplayBrightnessKey);
	
	BOOL errorOccurred = NO;
	CGDirectDisplayID display[kMaxDisplays];
	CGDisplayCount numDisplays;
	CGDisplayErr err;
	
	// get list of displays
	err = CGGetActiveDisplayList(kMaxDisplays, display, &numDisplays);
	if (err != CGDisplayNoErr) {
		DSLog(@"Cannot get list of displays (error %d)", err);
		errorOccurred = YES;
	}
	
	// loop through displays
	for (CGDisplayCount i = 0; i < numDisplays; ++i) {
		CGDirectDisplayID dspy = display[i];
		io_service_t service = CGDisplayIOServicePort(dspy);
		
		// set brightness
		err = IODisplaySetFloatParameter(service, kNilOptions, kDisplayBrightness, (brightness / 100.0));
		if (err != kIOReturnSuccess) {
			DSLog(@"Failed to set brightness of display 0x%x (error %d)", (unsigned int)dspy, err);
			errorOccurred = YES;
			continue;
		}
	}
	
	if (errorOccurred) {
		*errorString = [NSString stringWithFormat: NSLocalizedString(@"Failed setting brightness to %@%%.", @""), brightnessText];
		return NO;
	} else
		return YES;
}

+ (NSString *) helpText {
	return NSLocalizedString(@"The parameter for the Display Brightness action is the brightness value as a percent between 0 and 100.", @"");
}

+ (NSString *) creationHelpText {
	return NSLocalizedString(@"Set display brightness to (percent):", @"");
}

@end
