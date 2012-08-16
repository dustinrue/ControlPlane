//
//	DisplayBrightnessAction.m
//	ControlPlane
//
//	Created by David Jennes on 02/09/11.
//  Modifiedy by Dustin Rue on 19/11/11.
//  inspired by http://dev.sabi.net/trac/dev/browser/trunk/LocationDo/brightness.m
//
//	Copyright 2011. All rights reserved.
//

#import "DisplayBrightnessAction.h"
#import "DSLogger.h"
#import <IOKit/graphics/IOGraphicsLib.h>

const int kMaxDisplays = 16;
const CFStringRef kDisplayBrightness = CFSTR(kIODisplayBrightnessKey);

#pragma mark Magic Bits!

@interface O3Manager : NSObject
+ (void)initialize;
+ (id)engineOfClass:(NSString *)cls forDisplayID:(CGDirectDisplayID)fp12;
@end
	
@protocol O3EngineWireProtocol
@end
	
@protocol BrightnessEngineWireProtocol <O3EngineWireProtocol>
- (float)brightness;
- (BOOL)setBrightness:(float)fp8;
- (void)bumpBrightnessUp;
- (void)bumpBrightnessDown;
@end





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
	brightness = (unsigned int) [brightnessText floatValue];
	
	// must be between 0 and 100
	brightness = (brightness > 100) ? 100 : brightness;
	brightnessText = [[NSString stringWithFormat: @"%ld", [[NSNumber numberWithFloat:brightness] integerValue]] copy];
	
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

    CGDirectDisplayID display[kMaxDisplays];
	CGDisplayCount numDisplays;
	CGDisplayErr err;
	err = CGGetActiveDisplayList(kMaxDisplays, display, &numDisplays);
    
    BOOL errorOccurred = NO;
	
	if (err != CGDisplayNoErr) {
        errorOccurred = YES;
		DSLog(@"cannot get list of displays (error %d)\n",err);
    }
    
	for (CGDisplayCount i = 0; i < numDisplays; ++i) {
		
		
		CGDirectDisplayID dspy = display[i];
		//CFDictionaryRef originalMode = CGDisplayCurrentMode(dspy);
        CGDisplayModeRef originalMode = CGDisplayCopyDisplayMode(dspy);
        
		if (originalMode == NULL)
			continue;
        
        io_service_t service = CGDisplayIOServicePort(dspy);
        
        CFRelease(originalMode);
		

		err= IODisplayGetFloatParameter(service, kNilOptions, kDisplayBrightness,
										&old_brightness);
		if (err != kIOReturnSuccess) {
            // don't mark this as a failure for the whole action, it simply
            // means that this display doesn't support programattic brightness
            // control
            //errorOccurred = YES;
			DSLog(@"failed to get brightness of display 0x%x (error %d)",
					(unsigned int)dspy, err);
			continue;
		}
        
		err = IODisplaySetFloatParameter(service, kNilOptions, kDisplayBrightness,
										 brightness/100);
		if (err != kIOReturnSuccess) {
            errorOccurred = YES;
			DSLog(@"Failed to set brightness of display 0x%x (error %d)",
                    (unsigned int)dspy, err);
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

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Display Brightness", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"System Preferences", @"");
}

+ (BOOL) shouldWaitForScreensaverExit {
    return YES;
}

+ (BOOL) shouldWaitForScreenUnlock {
    return YES;
}

@end
