//
//	AudioOutputSource.m
//	ControlPlane
//
//	Created by David Jennes on 21/09/11.
//	Copyright 2011. All rights reserved.
//

#import "AudioOutputSource.h"
#import <CoreAudio/CoreAudio.h>

static OSStatus sourceChange(AudioObjectID inDevice, UInt32 inChannel,
							 const AudioObjectPropertyAddress *inPropertyID, void *inClientData);

@implementation AudioOutputSource

registerSourceType(AudioOutputSource)
@synthesize source = m_source;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_deviceID = 0;
	self.source = 0;
	
	return self;
}

#pragma mark - Required implementation of 'CallbackSource' class

- (NSArray *) observableKeys {
	return [NSArray arrayWithObject: @"source"];
}

- (void) registerCallback {
	OSStatus result;
	UInt32 sz = sizeof(m_deviceID);
	AudioObjectPropertyAddress address = {
		kAudioHardwarePropertyDefaultSystemOutputDevice,
		kAudioObjectPropertyScopeGlobal,
		kAudioObjectPropertyElementMaster
	};
	
	// get default output property
	result = AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, &sz, &m_deviceID);
	ZAssert(result != noErr, @"AudioHardwareGetProperty failed!");
	
	// register for change callback
	address.mSelector = kAudioHardwarePropertyDefaultSystemOutputDevice;
	result = AudioObjectAddPropertyListener((UInt32) m_deviceID, &address, &sourceChange, self);
	ZAssert(result != noErr, @"AudioDeviceAddPropertyListener failed!");
}

- (void) unregisterCallback {
	AudioObjectPropertyAddress address = {
		kAudioDevicePropertyStreamFormat,
		kAudioObjectPropertyScopeGlobal,
		kAudioObjectPropertyElementMaster
	};
	
	// Unregister listener
	AudioObjectRemovePropertyListener(kAudioObjectSystemObject, &address, &sourceChange, self);
}

- (void) checkData {
	OSStatus result;
	UInt32 sourceID;
	UInt32 sz = sizeof(sourceID);
	AudioObjectPropertyAddress address = {
		kAudioDevicePropertyDataSource,
		kAudioDevicePropertyScopeOutput,
		0
	};
	
	// get default output
	result = AudioObjectGetPropertyData((UInt32) m_deviceID, &address, 0, NULL, &sz, &sourceID);
	ZAssert(result != noErr, @"AudioDeviceGetProperty failed!");
	
	DLog(@"%@ >> Got 0x%08lu", [self class], (unsigned long) sourceID);
	
	// store it
	if (self.source != sourceID)
		self.source = sourceID;
}

static OSStatus sourceChange(AudioObjectID inDevice, UInt32 inChannel,
							 const AudioObjectPropertyAddress *inPropertyID,
							 void *inClientData) {
	
	AudioOutputSource *src = (AudioOutputSource *) inClientData;
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[src checkData];
	[pool release];
	
	return 0;
}

@end
