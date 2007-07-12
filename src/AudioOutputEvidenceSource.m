//
//  AudioOutputEvidenceSource.m
//  MarcoPolo
//
//  Created by David Symonds on 11/07/07.
//

#import <CoreAudio/CoreAudio.h>
#import "AudioOutputEvidenceSource.h"


static OSStatus sourceChange(AudioDeviceID inDevice, UInt32 inChannel, Boolean isInput,
			     AudioDevicePropertyID inPropertyID, void *inClientData)
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

	source = nil;
	[self setDataCollected:NO];

	return self;
}

- (void)dealloc
{
	if (source)
		[source release];

	[super dealloc];
}

- (void)doRealUpdate
{
	UInt32 sourceID;
	UInt32 sz = sizeof(sourceID);
	if (AudioDeviceGetProperty(deviceID, 0, 0, kAudioDevicePropertyDataSource, &sz, &sourceID) != noErr) {
		NSLog(@"%@ >> AudioDeviceGetProperty failed!", [self class]);
		return;
	}

	char raw[5] = { (sourceID >> 24) & 0xFF, (sourceID >> 16) & 0xFF, (sourceID >> 8) & 0xFF, sourceID & 0xFF, 0 };
	NSString *newSource = [[NSString stringWithCString:raw encoding:NSMacOSRomanStringEncoding] retain];
	if (source)
		[source autorelease];
	source = newSource;
	[self setDataCollected:YES];

#ifdef DEBUG_MODE
	NSLog(@"%@ >> Got 0x%08x (%@)", [self class], sourceID, source);
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
	if (!source)
		return NO;
	return [[rule objectForKey:@"parameter"] isEqualToString:source];
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
			@"ispk", @"parameter",
			NSLocalizedString(@"Internal speakers", @""), @"description", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"AudioOutput", @"type",
			@"hdpn", @"parameter",
			NSLocalizedString(@"Headphones", @""), @"description", nil],
		nil];
}

- (void)start
{
	if (running)
		return;

	// Register listener
	UInt32 sz = sizeof(deviceID);
	if (AudioHardwareGetProperty(kAudioHardwarePropertyDefaultSystemOutputDevice, &sz, &deviceID) != noErr) {
		NSLog(@"%s >> AudioHardwareGetProperty failed!", __PRETTY_FUNCTION__);
		return;
	}
	if (AudioDeviceAddPropertyListener(deviceID, 0, 0, kAudioDevicePropertyDataSource, &sourceChange, self) != noErr) {
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

	// Unregister listener; I don't know what we could do if this fails ...
	AudioDeviceRemovePropertyListener(deviceID, 0, 0, kAudioDevicePropertyDataSource, &sourceChange);

	if (source) {
		[source release];
		source = nil;
	}
	[self setDataCollected:NO];

	running = NO;
}

@end
