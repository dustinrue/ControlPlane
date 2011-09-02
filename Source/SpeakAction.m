//
//	SpeakAction.m
//	ControlPlane
//
//	Created by David Jennes on 02/09/11.
//	Copyright 2011. All rights reserved.
//

#import "SpeakAction.h"

@implementation SpeakAction

- (id) init {
	self = [super init];
	if (!self)
		return nil;
	
	text = [[NSString alloc] init];
	synth = [[NSSpeechSynthesizer alloc] init];
	
	return self;
}

- (id) initWithDictionary: (NSDictionary *) dict {
	self = [super initWithDictionary: dict];
	if (!self)
		return nil;
	
	text = [[dict valueForKey: @"parameter"] copy];
	synth = [[NSSpeechSynthesizer alloc] init];
	
	return self;
}

- (void) dealloc {
	[text release];
	[synth release];
	
	[super dealloc];
}

- (NSMutableDictionary *) dictionary {
	NSMutableDictionary *dict = [super dictionary];
	
	[dict setObject:[[text copy] autorelease] forKey: @"parameter"];
	
	return dict;
}

- (NSString *) description {
	return [NSString stringWithFormat: NSLocalizedString(@"Speak text '%@'.", @""), text];
}

- (BOOL) execute: (NSString **) errorString {
	if ([synth startSpeakingString: text])
		 return YES;
	
	*errorString = [NSString stringWithFormat: NSLocalizedString(@"Failed speaking '%@'.", @""), text];
	return NO;
}

+ (NSString *) helpText {
	return NSLocalizedString(@"The parameter for the Speak action is the text to be spoken.", @"");
}

+ (NSString *) creationHelpText {
	return NSLocalizedString(@"Speak text:", @"");
}

@end
