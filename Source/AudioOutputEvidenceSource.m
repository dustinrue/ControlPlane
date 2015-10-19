//
//  AudioOutputEvidenceSource.m
//  ControlPlane
//
//  Created by David Symonds on 11/07/07.
//  Updated by Dustin Rue 9/7/2012
//

#import "AudioOutputEvidenceSource.h"
#import <CoreAudio/CoreAudio.h>
#import <IOKit/audio/IOAudioTypes.h>


static OSStatus sourceChange(AudioObjectID inDevice, UInt32 inChannel,
			     const AudioObjectPropertyAddress *inPropertyID, void *inClientData) {
    
	AudioOutputEvidenceSource *src = (AudioOutputEvidenceSource *) inClientData;

	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[src doRealUpdate];
	[pool release];

	return 0;
}

@implementation AudioOutputEvidenceSource

- (id)init
{
	if (!(self = [super init]))
		return nil;

	source = 0;

	return self;
}


- (NSString *) description {
    return NSLocalizedString(@"Create rules based on what audio output device is currently in use.", @"");
}

- (void)doRealUpdate
{
    
    UInt32 sz2 = sizeof(deviceID);
    AudioObjectPropertyAddress address2 = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };
    
    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &address2, 0, NULL, &sz2, &deviceID) != noErr) {
        NSLog(@"%s >> AudioHardwareGetProperty failed!", __PRETTY_FUNCTION__);
        return;
    }
    NSLog(@"current device id %u", (unsigned int) deviceID);
    
    
    
	UInt32 sourceID;
	UInt32 sz = sizeof(sourceID);
	
	AudioObjectPropertyAddress address = {
		kAudioDevicePropertyDataSource,
		kAudioDevicePropertyScopeOutput,
		0
	};
	
    if (AudioObjectGetPropertyData((builtinDeviceID == deviceID) ? builtinDeviceID:deviceID, &address, 0, NULL, &sz, &sourceID) != noErr) {
		NSLog(@"%@ >> AudioDeviceGetProperty failed!", [self class]);
        sourceID = kIOAudioOutputPortSubTypeExternalSpeaker;
	}
	source = sourceID;
	[self setDataCollected:YES];

#ifdef DEBUG_MODE
	NSLog(@"%@ >> Got 0x%08lu", [self class], (unsigned long) sourceID);
#endif
    [[NSNotificationCenter defaultCenter] postNotificationName:@"evidenceSourceDataDidChange" object:nil];
	// 0x6973706b ('ispk') => Internal speakers
	// 0x6864706e ('hdpn') => Headphones
	// ... any others? (see IOAudioPortSubtypes enum)
}

- (NSString *)name
{
	return @"AudioOutput";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule
{
	return (((UInt32) [[rule objectForKey:@"parameter"] intValue]) == source);
}

- (NSString *)getSuggestionLeadText:(NSString *)type
{
	return NSLocalizedString(@"Audio output going to", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions
{
	return [NSArray arrayWithObjects:
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"AudioOutput", @"type",
			[NSNumber numberWithInt:kIOAudioOutputPortSubTypeInternalSpeaker], @"parameter",
			NSLocalizedString(@"Internal speakers", @""), @"description", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"AudioOutput", @"type",
			[NSNumber numberWithInt:kIOAudioOutputPortSubTypeHeadphones], @"parameter",
			NSLocalizedString(@"Headphones", @""), @"description", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"AudioOutput", @"type",
			[NSNumber numberWithInt:kIOAudioOutputPortSubTypeExternalSpeaker], @"parameter",
			NSLocalizedString(@"External speakers", @""), @"description", nil],
		nil];
}

- (void)start
{
	if (running)
		return;

	// Register listener for the default output device
    // This one detects when the audio source has changed at all
	UInt32 sz = sizeof(deviceID);
	AudioObjectPropertyAddress address = {
		kAudioHardwarePropertyDefaultOutputDevice,
		kAudioObjectPropertyScopeGlobal,
		kAudioObjectPropertyElementMaster
	};
	
	if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, &sz, &deviceID) != noErr) {
		NSLog(@"%s >> AudioHardwareGetProperty failed!", __PRETTY_FUNCTION__);
		return;
	}
    NSLog(@"current device id %u", (unsigned int) deviceID);
	
	address.mSelector = kAudioHardwarePropertyDefaultOutputDevice;
	
	if (AudioObjectAddPropertyListener(kAudioObjectSystemObject, &address, &sourceChange, self) != noErr) {
		NSLog(@"%s >> AudioDeviceAddPropertyListener failed!", __PRETTY_FUNCTION__);
		return;
	}
    
    // Register a lister for the built in audio device
    // this one is able to detect when the built in audio
    // device has changed from headphones to internal
    
    // we need to find the built in device first
    AudioObjectPropertyAddress availableDeviceSearch = {
        kAudioHardwarePropertyDevices,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster,
    };
    
    UInt32 propertySize;
    
    if (AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &availableDeviceSearch, 0, NULL, &propertySize) != noErr) {
        NSLog(@"%s >> Unable to get property data size while getting available audio output devices", __PRETTY_FUNCTION__);
        return;
    }
    
    int deviceCount = propertySize / sizeof(AudioDeviceID);
    AudioDeviceID *audioDevices = (AudioDeviceID *)malloc(propertySize);
    builtinDeviceID = 0;
    OSStatus error = noErr;
    
    error = AudioObjectGetPropertyData(kAudioObjectSystemObject, &availableDeviceSearch, 0, NULL, &propertySize, audioDevices);
    if (error == noErr) {
        propertySize = sizeof(CFStringRef);
        // for each of the audio deviceds we were given, check to see if it is named
        // Built-in Output
        for (int i = 0; i <= deviceCount; i++) {
            NSString *result;
            availableDeviceSearch.mSelector = kAudioDevicePropertyDeviceNameCFString;
            error = AudioObjectGetPropertyData(audioDevices[i], &availableDeviceSearch, 0, NULL, &propertySize, &result);
            if (error == noErr && [result isEqualToString:@"Built-in Output"]) {
                builtinDeviceID = audioDevices[i];
                break;
            }
        }

    }
    free(audioDevices);
    
    if (builtinDeviceID == 0) {
        NSLog(@"%s >> Failed to find built in audio device", __PRETTY_FUNCTION__);
        return;
    }
    NSLog(@"built in device id %u", (unsigned int) builtinDeviceID);
    

    AudioObjectPropertyAddress sourceAddr = {
        kAudioDevicePropertyDataSource,
        kAudioDevicePropertyScopeOutput,
        kAudioObjectPropertyElementMaster
    };
    
    if (AudioObjectAddPropertyListener(builtinDeviceID, &sourceAddr, &sourceChange, self) != noErr) {
        NSLog(@"%s >> AudioDeviceAddPropertyListener failed!", __PRETTY_FUNCTION__);
        return;
    }


	[self doRealUpdate];

	running = YES;
}

- (void)stop
{
	if (!running)
		return;
	
	AudioObjectPropertyAddress address = {
		kAudioHardwarePropertyDefaultOutputDevice,
		kAudioObjectPropertyScopeGlobal,
		kAudioObjectPropertyElementMaster
	};
	
	// Unregister listener; I don't know what we could do if this fails ...
	AudioObjectRemovePropertyListener(kAudioObjectSystemObject, &address, &sourceChange, self);
    
    address.mSelector =kAudioDevicePropertyDataSource;
    address.mScope = kAudioDevicePropertyScopeOutput;
    address.mElement = kAudioObjectPropertyElementMaster;
    AudioObjectRemovePropertyListener(builtinDeviceID, &address, &sourceChange, self);

	source = 0;
	[self setDataCollected:NO];

	running = NO;
}

- (NSString *) friendlyName {
    return NSLocalizedString(@"Audio Output", @"");
}

@end
