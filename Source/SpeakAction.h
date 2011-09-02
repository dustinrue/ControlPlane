//
//	SpeakAction.h
//	ControlPlane
//
//	Created by David Jennes on 02/09/11.
//	Copyright 2011. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Action.h"

@interface SpeakAction : Action <ActionWithString> {
	NSString *text;
	NSSpeechSynthesizer *synth;
}

- (id) initWithDictionary: (NSDictionary *) dict;
- (void) dealloc;
- (NSMutableDictionary *) dictionary;

- (NSString *) description;
- (BOOL) execute: (NSString **) errorString;
+ (NSString *) helpText;
+ (NSString *) creationHelpText;

@end
