//
//	SpeakAction.h
//	ControlPlane
//
//	Created by David Jennes on 02/09/11.
//	Copyright 2011. All rights reserved.
//
//  Minor improvements by Vladimir Beloborodov (VladimirTechMan) on 21 July 2013.
//

#import "Action.h"

@interface SpeakAction: Action <ActionWithString, NSSpeechSynthesizerDelegate>

- (id) initWithDictionary: (NSDictionary *) dict;
- (NSMutableDictionary *) dictionary;

- (NSString *) description;
- (BOOL) execute: (NSString **) errorString;
+ (NSString *) helpText;
+ (NSString *) creationHelpText;

@end
