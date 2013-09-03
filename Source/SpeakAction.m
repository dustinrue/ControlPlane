//
//	SpeakAction.m
//	ControlPlane
//
//	Created by David Jennes on 02/09/11.
//	Copyright 2011. All rights reserved.
//
//  Minor improvements by Vladimir Beloborodov (VladimirTechMan) on 21 July 2013.
//
//  IMPORTANT: This code is intended to be compiled for the ARC mode
//

#import "SpeakAction.h"

@interface SpeakAction () {
	NSString *text;
}

@property (strong,atomic,readwrite) NSSpeechSynthesizer *synth;

- (void)speechSynthesizer:(NSSpeechSynthesizer *)sender didFinishSpeaking:(BOOL)success;
- (void)speechSynthesizer:(NSSpeechSynthesizer *)sender didEncounterErrorAtIndex:(NSUInteger)characterIndex
                 ofString:(NSString *)string message:(NSString *)message;

@end

@implementation SpeakAction

- (id)init {
	self = [super init];
	if (!self) {
		return nil;
    }
	
	text = [[NSString alloc] init];
	
	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict {
	self = [super initWithDictionary: dict];
	if (!self) {
		return nil;
    }

	text = [dict[@"parameter"] copy];

	return self;
}

- (NSMutableDictionary *)dictionary {
	NSMutableDictionary *dict = [super dictionary];
    dict[@"parameter"] = [text copy];
	return dict;
}

- (NSString *)description {
	return [NSString stringWithFormat:NSLocalizedString(@"Speak text '%@'.", @""), text];
}

- (void)speechSynthesizer:(NSSpeechSynthesizer *)sender didFinishSpeaking:(BOOL)success {
    self.synth = nil;
}

- (void)speechSynthesizer:(NSSpeechSynthesizer *)sender didEncounterErrorAtIndex:(NSUInteger)characterIndex
                 ofString:(NSString *)string message:(NSString *)message {
    self.synth = nil;
}

- (BOOL)execute:(NSString **)errorString {
    NSSpeechSynthesizer *synth = self.synth;
    if (!synth) {
        self.synth = synth = [[NSSpeechSynthesizer alloc] init];
        [synth setDelegate:self];
    }
    
	BOOL success = [synth startSpeakingString:text];
    if (!success) {
        *errorString = [NSString stringWithFormat:NSLocalizedString(@"Failed speaking '%@'.", @""), text];
        self.synth = nil;
    }
	return success;
}

+ (NSString *)helpText {
	return NSLocalizedString(@"The parameter for the Speak action is the text to be spoken.", @"");
}

+ (NSString *)creationHelpText {
	return NSLocalizedString(@"Speak text:", @"");
}

+ (NSString *)friendlyName {
    return NSLocalizedString(@"Speak Phrase", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"Misc", @"");
}

@end
