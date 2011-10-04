//
//	AudioOutputRule.m
//	ControlPlane
//
//	Created by David Jennes on 24/09/11.
//	Copyright 2011. All rights reserved.
//

#import "AudioOutputRule.h"
#import "AudioSource.h"
#import <IOKit/audio/IOAudioTypes.h>

@implementation AudioOutputRule

registerRuleType(AudioOutputRule)

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_output = nil;
	
	return self;
}

#pragma mark - Source observe functions

- (void) outputChangedWithOld: (NSNumber *) oldOutput andNew: (NSNumber *) newOutput {
	self.match = [m_output isEqualToNumber: newOutput];
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"Audio Output", @"Rule type");
}

- (NSString *) category {
	return NSLocalizedString(@"System", @"Rule category");
}

- (void) beingEnabled {
	Source *source = [SourcesManager.sharedSourcesManager registerRule: self toSource: @"AudioSource"];
	
	// currently a match?
	[self outputChangedWithOld: 0 andNew: ((AudioSource *) source).output];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unRegisterRule: self fromSource: @"AudioSource"];
}

- (void) loadData {
	m_output = [self.data objectForKey: @"parameter"];
}

- (NSArray *) suggestedValues {
	AudioSource *source = (AudioSource *) [SourcesManager.sharedSourcesManager getSource: @"AudioSource"];
	NSMutableArray *result = [[NSArray new] autorelease];
	NSString *typeName = NSLocalizedString(@"output", @"AudioSource");
	
	// loop through devices
	for (NSNumber *device in source.devices) {
		NSString *name = [source.devices objectForKey: device];
		
		// only output devices
		if ([name rangeOfString: typeName].location != NSNotFound)
			[result addObject: [NSDictionary dictionaryWithObjectsAndKeys:
								device, @"parameter",
								name, @"description", nil]];
	}
	
	return result;
}

@end
