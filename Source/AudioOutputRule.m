//
//	AudioOutputRule.m
//	ControlPlane
//
//	Created by David Jennes on 24/09/11.
//	Copyright 2011. All rights reserved.
//

#import "AudioOutputRule.h"
#import "AudioOutputSource.h"
#import <IOKit/audio/IOAudioTypes.h>

@implementation AudioOutputRule

registerRuleType(AudioOutputRule)

#pragma mark - Source observe functions

- (void) sourceChangedWithOld: (UInt32) oldSource andNew: (UInt32) newSource {
	UInt32 param = (UInt32) [[self.data objectForKey: @"parameter"] intValue];
	
	self.match = (param == newSource);
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"Audio Output", @"Rule type");
}

- (void) beingEnabled {
	Source *source = [SourcesManager.sharedSourcesManager registerRule: self toSource: @"AudioOutputSource"];
	
	// currently a match?
	[self sourceChangedWithOld: 0 andNew: ((AudioOutputSource *) source).source];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unRegisterRule: self fromSource: @"AudioOutputSource"];
}

- (NSArray *) suggestedValues {
	return [NSArray arrayWithObjects:
			[NSDictionary dictionaryWithObjectsAndKeys:
			 [NSNumber numberWithInt: kIOAudioOutputPortSubTypeInternalSpeaker], @"parameter",
			 NSLocalizedString(@"Internal Speakers", @"AudioOutputRule suggestion description"), @"description",
			 nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
			 [NSNumber numberWithInt: kIOAudioOutputPortSubTypeHeadphones], @"parameter",
			 NSLocalizedString(@"Headphones", @"AudioOutputRule suggestion description"), @"description",
			 nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
			 [NSNumber numberWithInt: kIOAudioOutputPortSubTypeExternalSpeaker], @"parameter",
			 NSLocalizedString(@"External speakers", @"AudioOutputRule suggestion description"), @"description",
			 nil],
			nil];
}

@end
