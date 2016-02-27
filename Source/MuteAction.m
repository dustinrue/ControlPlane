//
//  MuteAction.m
//  ControlPlane
//
//  Created by David Symonds on 7/06/07.
//

#import "MuteAction.h"
#import <CoreAudio/CoreAudio.h>
#import <AudioToolbox/AudioServices.h>

@interface MuteAction (Private)

- (AudioDeviceID) outputDeviceID;
- (AudioDeviceID) outputHardwareDeviceID;

@end

@implementation MuteAction

- (NSString *) description {
	if (turnOn)
		return NSLocalizedString(@"Unmuting system audio.", @"");
	else
		return NSLocalizedString(@"Muting system audio.", @"");
}

- (BOOL) execute: (NSString **) errorString {
	AudioDeviceID deviceID = [self outputHardwareDeviceID];
	
	// init
	OSStatus status = noErr;
	AudioObjectPropertyAddress property;
	property.mScope = kAudioDevicePropertyScopeOutput;
	property.mElement = kAudioObjectPropertyElementMaster;
	property.mSelector = kAudioDevicePropertyMute;
	
	// check device
	if (deviceID == kAudioObjectUnknown) {
		*errorString = @"Unkown output device.";
		return NO;
	}
	
	// supports volume control?
	if (!AudioHardwareServiceHasProperty(deviceID, &property)) {
		*errorString = @"Output device does not support volume control.";
		return NO;
	}
	
	// is settable
	Boolean settable = NO;
	status = AudioHardwareServiceIsPropertySettable(deviceID, &property, &settable);
	if (status || !settable) {
		*errorString = @"Output device does not support volume control.";
		return NO;
	}
	
	// mute/unmute
    UInt32 mute = (turnOn) ? 0:1;
    AudioDeviceID deviceID2 = [self outputDeviceID];
    status = AudioObjectSetPropertyData(deviceID2, &property, 0, NULL, sizeof(UInt32), &mute);

	// result
	if (status) {
		*errorString = @"Unable to set volume for output device.";
		return NO;
	} else
		return YES;
}

+ (NSString *) helpText {
	return NSLocalizedString(@"The parameter for Mute actions is either \"1\" "
				 "or \"0\", depending on whether you want your system audio "
				 "unmuted or muted.", @"");
}

+ (NSString *) creationHelpText {
	// FIXME: is there some useful text we could use?
	return NSLocalizedString(@"Toggle muting of system audio", @"");
}

+ (NSArray *) limitedOptions {
	return [NSArray arrayWithObjects:
		[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], @"option",
			NSLocalizedString(@"Mute system audio", @""), @"description", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"option",
			NSLocalizedString(@"Unmute system audio", @""), @"description", nil],
		nil];
}

- (AudioDeviceID) outputDeviceID {
	AudioDeviceID deviceID = kAudioObjectUnknown;
	
	// init
	UInt32 size = 0;
	OSStatus status = noErr;
	AudioObjectPropertyAddress property;
	property.mScope = kAudioObjectPropertyScopeGlobal;
	property.mElement = kAudioObjectPropertyElementMaster;
	property.mSelector = kAudioHardwarePropertyDefaultOutputDevice;
	
	// are there audio properties
	if (!AudioHardwareServiceHasProperty(kAudioObjectSystemObject, &property)) 
		NSLog(@"Cannot find default output device!");
	else {
		// get the default output
		size = sizeof(deviceID);
        status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &property, 0, NULL, &size, &deviceID);
		
		if (status)
			NSLog(@"Cannot find default output device!");
	}
	
	return deviceID;
}
- (AudioDeviceID) outputHardwareDeviceID {
  AudioDeviceID deviceID = kAudioObjectUnknown;
  
  // init
  UInt32 size = 0;
  OSStatus status = noErr;
  AudioObjectPropertyAddress property;
  property.mScope = kAudioObjectPropertyScopeGlobal;
  property.mElement = kAudioObjectPropertyElementMaster;
  property.mSelector = kAudioHardwarePropertyDefaultOutputDevice;
  
  // are there audio properties
  if (!AudioHardwareServiceHasProperty(kAudioObjectSystemObject, &property))
    NSLog(@"Cannot find default output device!");
  else {
    // get the default output
    size = sizeof(deviceID);
    status = AudioHardwareServiceGetPropertyData(kAudioObjectSystemObject, &property, 0, NULL, &size, &deviceID);
    
    if (status)
      NSLog(@"Cannot find default output device!");
  }
  
  return deviceID;
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Mute", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"Sound and Music", @"");
}

@end
