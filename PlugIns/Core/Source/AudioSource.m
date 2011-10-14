//
//	AudioSource.m
//	ControlPlane
//
//	Created by David Jennes on 21/09/11.
//	Copyright 2011. All rights reserved.
//

#import "AudioSource.h"
#import <CoreAudio/CoreAudio.h>

static OSStatus sourceChange(AudioObjectID inDevice, UInt32 inChannel,
							 const AudioObjectPropertyAddress *inPropertyID, void *inClientData);

typedef enum { 
	kAudioTypeUnknown = 0, 
	kAudioTypeInput = 1, 
	kAudioTypeOutput = 2,
	kAudioTypeSystemOutput = 3
} DeviceType;

@interface AudioSource (Private)

- (AudioDeviceID) getDefaultDevice: (DeviceType) type;
- (NSString *) getDeviceName: (AudioDeviceID) deviceID;
- (NSString *) getDeviceType: (AudioDeviceID) deviceID;

@end

@implementation AudioSource

@synthesize devices = m_devices;
@synthesize input = m_input;
@synthesize output = m_output;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	self.devices = [NSDictionary new];
	self.input = [NSNumber numberWithUnsignedInt: 0];
	self.output = [NSNumber numberWithUnsignedInt: 0];
	
	return self;
}

#pragma mark - Required implementation of 'CallbackSource' class

- (NSArray *) observableKeys {
	return [NSArray arrayWithObjects: @"devices", @"input", @"output", nil];
}

- (void) registerCallback {
	OSStatus result;
	AudioObjectPropertyAddress address = {
		kAudioHardwarePropertyDefaultSystemOutputDevice,
		kAudioObjectPropertyScopeGlobal,
		kAudioObjectPropertyElementMaster
	};
	void *selfVoid = (__bridge void *) self;
	
	// register for output change
	result = AudioObjectAddPropertyListener([self getDefaultDevice: kAudioTypeOutput], &address, &sourceChange, selfVoid);
	ZAssert(result != noErr, @"AudioDeviceAddPropertyListener failed!");
	
	// register for input change
	address.mSelector = kAudioHardwarePropertyDefaultInputDevice;
	result = AudioObjectAddPropertyListener([self getDefaultDevice: kAudioTypeInput], &address, &sourceChange, selfVoid);
	ZAssert(result != noErr, @"AudioDeviceAddPropertyListener failed!");
	
	// register for devices list change
	address.mSelector = kAudioHardwarePropertyDevices;
	result = AudioObjectAddPropertyListener(kAudioObjectSystemObject, &address, &sourceChange, selfVoid);
	ZAssert(result != noErr, @"AudioDeviceAddPropertyListener failed!");
}

- (void) unregisterCallback {
	AudioObjectPropertyAddress address = {
		kAudioDevicePropertyStreamFormat,
		kAudioObjectPropertyScopeGlobal,
		kAudioObjectPropertyElementMaster
	};
	
	// Unregister listener
	AudioObjectRemovePropertyListener(kAudioObjectSystemObject, &address, &sourceChange, (__bridge void *) self);
}

- (void) checkData {
	NSMutableDictionary *devices = [NSMutableDictionary new];
	OSStatus result;
	AudioDeviceID list[64];
	AudioObjectPropertyAddress address = {
		kAudioHardwarePropertyDevices,
		kAudioObjectPropertyScopeGlobal,
		kAudioObjectPropertyElementMaster
	};
	
	// get list device of devices
	UInt32 propertySize;
	result = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &address, 0, NULL, &propertySize);
	ZAssert(result != noErr, @"AudioObjectGetPropertyDataSize failed!");
	result = AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, &propertySize, list);
	ZAssert(result != noErr, @"AudioObjectGetPropertyData failed!");
	NSUInteger total = (propertySize / sizeof(AudioDeviceID));
	
	// process list
	for (NSUInteger i = 0; i < total; ++i)
		[devices setObject: [NSString stringWithFormat: @"%@ (%@)",
							 [self getDeviceName: list[i]],
							 [self getDeviceType: list[i]]]
					forKey: [NSNumber numberWithUnsignedInt: list[i]]];
	
	// get default input & output
	NSNumber *input = [NSNumber numberWithUnsignedInt: [self getDefaultDevice: kAudioTypeInput]];
	NSNumber *output = [NSNumber numberWithUnsignedInt: [self getDefaultDevice: kAudioTypeOutput]];
	
	// store it
	if (![self.devices isEqualToDictionary: devices])
		self.devices = devices;
	if (![self.input isEqualToNumber: input])
		self.input = input;
	if (![self.output isEqualToNumber: output])
		self.output = output;
}

#pragma mark - Internal callbacks

static OSStatus sourceChange(AudioObjectID inDevice, UInt32 inChannel,
							 const AudioObjectPropertyAddress *inPropertyID,
							 void *inClientData) {
	
	AudioSource *src = (__bridge AudioSource *) inClientData;
	
	@autoreleasepool {
		[src checkData];
	}
	
	return 0;
}

#pragma mark - Utility methods

- (AudioDeviceID) getDefaultDevice: (DeviceType) type {
	AudioDeviceID deviceID = kAudioDeviceUnknown;
	AudioObjectPropertyAddress address = {
		0,
		kAudioObjectPropertyScopeGlobal,
		kAudioObjectPropertyElementMaster
	};
	
	// which type 
	switch(type) {
		case kAudioTypeInput: 
			address.mSelector = kAudioHardwarePropertyDefaultInputDevice;
			break;
		case kAudioTypeOutput:
			address.mSelector = kAudioHardwarePropertyDefaultOutputDevice;
			break;
		case kAudioTypeSystemOutput:
			address.mSelector = kAudioHardwarePropertyDefaultSystemOutputDevice;
			break;
        default: break;
			
	}
	
	// get device ID
	UInt32 propertySize = sizeof(deviceID);
	OSStatus result = AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, &propertySize, &deviceID);
	ZAssert(result != noErr, @"AudioObjectGetPropertyData failed!");
	
	return deviceID;
}

- (NSString *) getDeviceName: (AudioDeviceID) deviceID {
	char name[256];
	AudioObjectPropertyAddress address = {
		kAudioDevicePropertyDeviceName,
		kAudioObjectPropertyScopeGlobal,
		kAudioObjectPropertyElementMaster
	};
	
	// get name
	UInt32 propertySize = 256;
	OSStatus result = AudioObjectGetPropertyData(deviceID, &address, 0, NULL, &propertySize, &name);
	ZAssert(result != noErr, @"AudioObjectGetPropertyData failed!");
	
	return [NSString stringWithUTF8String: name];
}

- (NSString *) getDeviceType: (AudioDeviceID) deviceID {
	UInt32 propertySize = 256;
	OSStatus result = 0;
	AudioObjectPropertyAddress address = {
		kAudioDevicePropertyStreams,
		kAudioDevicePropertyScopeOutput,
		kAudioObjectPropertyElementMaster
	};
	
	// if there are any output streams, then it is an output
	result = AudioObjectGetPropertyDataSize(deviceID, &address, 0, NULL, &propertySize);
	ZAssert(result != noErr, @"AudioObjectGetPropertyDataSize failed!");
	if (propertySize > 0)
		return NSLocalizedString(@"output", @"AudioSource");
	
	// if there are any input streams, then it is an input
	address.mScope = kAudioDevicePropertyScopeInput;
	result = AudioObjectGetPropertyDataSize(deviceID, &address, 0, NULL, &propertySize);
	ZAssert(result != noErr, @"AudioObjectGetPropertyDataSize failed!");
	if (propertySize > 0)
		return NSLocalizedString(@"input", @"AudioSource");
	
	return NSLocalizedString(@"unknown", @"AudioSource");
}

@end
