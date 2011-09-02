//
//  AudioOutputEvidenceSource.m
//  ControlPlane
//
//  Created by David Symonds on 11/07/07.
//

#import <Cocoa/Cocoa.h>
#import <CoreAudio/CoreAudio.h>
#import <IOKit/audio/IOAudioTypes.h>
#import "AudioOutputEvidenceSource.h"


static OSStatus sourceChange(AudioObjectID inDevice, UInt32 inChannel,
			     const AudioObjectPropertyAddress *inPropertyID, void *inClientData)
{
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

- (void)doRealUpdate
{
	UInt32 sourceID;
	UInt32 sz = sizeof(sourceID);
	
	AudioObjectPropertyAddress address = {
		kAudioDevicePropertyDataSource,
		kAudioDevicePropertyScopeOutput,
		0
	};
	
	if (AudioObjectGetPropertyData(deviceID, &address, 0, NULL, &sz, &sourceID) != noErr) {
		NSLog(@"%@ >> AudioDeviceGetProperty failed!", [self class]);
		return;
	}
	source = sourceID;
	[self setDataCollected:YES];

#ifdef DEBUG_MODE
	NSLog(@"%@ >> Got 0x%08lu", [self class], (unsigned long) sourceID);
#endif

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

	// Register listener
	UInt32 sz = sizeof(deviceID);
	AudioObjectPropertyAddress address = {
		kAudioHardwarePropertyDefaultSystemOutputDevice,
		kAudioObjectPropertyScopeGlobal,
		kAudioObjectPropertyElementMaster
	};
	
	if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, &sz, &deviceID) != noErr) {
		NSLog(@"%s >> AudioHardwareGetProperty failed!", __PRETTY_FUNCTION__);
		return;
	}
	
	address.mSelector = kAudioHardwarePropertyDefaultSystemOutputDevice;
	
	if (AudioObjectAddPropertyListener(deviceID, &address, &sourceChange, self) != noErr) {
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
		kAudioDevicePropertyStreamFormat,
		kAudioObjectPropertyScopeGlobal,
		kAudioObjectPropertyElementMaster
	};
	
	// Unregister listener; I don't know what we could do if this fails ...
	AudioObjectRemovePropertyListener(kAudioObjectSystemObject, &address, &sourceChange, self);

	source = 0;
	[self setDataCollected:NO];

	running = NO;
}

@end
