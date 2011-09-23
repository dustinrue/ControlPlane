//
//	AudioOutputSource.m
//	ControlPlane
//
//	Created by David Jennes on 21/09/11.
//	Copyright 2011. All rights reserved.
//

#import "AudioOutputSource.h"
#import "KVOAdditions.h"
#import "Rule.h"
#import "SourcesManager.h"

static OSStatus sourceChange(AudioObjectID inDevice, UInt32 inChannel,
							 const AudioObjectPropertyAddress *inPropertyID, void *inClientData);

@implementation AudioOutputSource

@synthesize source = m_source;

- (id) init {
	self = [super init];
	if (!self)
		return nil;
	
	m_deviceID = 0;
	self.source = 0;
	
	return self;
}

#pragma mark - Required implementation of 'Source' class

+ (void) load {
	[[SourcesManager sharedSourcesManager] registerSourceType: self];
}

- (void) addObserver: (Rule *) rule {
	SEL selector = NSSelectorFromString(@"sourceChangedWithOld:andNew:");
	
	[self addObserver: rule
		   forKeyPath: @"source"
			  options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
			 selector: selector];
}

- (void) removeObserver: (Rule *) rule {
	[self removeObserver: rule forKeyPath: @"source" selector: nil];
}

#pragma mark - CoreAudio stuff

- (void) registerCallback {
	UInt32 sz = sizeof(m_deviceID);
	AudioObjectPropertyAddress address = {
		kAudioHardwarePropertyDefaultSystemOutputDevice,
		kAudioObjectPropertyScopeGlobal,
		kAudioObjectPropertyElementMaster
	};
	
	// get default output property
	if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, &sz, &m_deviceID) != noErr) {
		NSLog(@"AudioHardwareGetProperty failed!");
		return;
	}
	
	// register for change callback
	address.mSelector = kAudioHardwarePropertyDefaultSystemOutputDevice;
	if (AudioObjectAddPropertyListener(m_deviceID, &address, &sourceChange, self) != noErr) {
		NSLog(@"AudioDeviceAddPropertyListener failed!");
		return;
	}
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
	UInt32 sourceID;
	UInt32 sz = sizeof(sourceID);
	AudioObjectPropertyAddress address = {
		kAudioDevicePropertyDataSource,
		kAudioDevicePropertyScopeOutput,
		0
	};
	
	// get default output
	if (AudioObjectGetPropertyData(m_deviceID, &address, 0, NULL, &sz, &sourceID) != noErr) {
		NSLog(@"AudioDeviceGetProperty failed!");
		return;
	}
	
	NSLog(@"%@ >> Got 0x%08lu", [self class], (unsigned long) sourceID);
	
	// store it
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
