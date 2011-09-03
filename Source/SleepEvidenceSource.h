//
//  SleepEvidenceSource.h
//  ControlPlane
//
//  Created by David Jennes on 21/08/11.
//  Copyright 2011. All rights reserved.
//

#import "GenericEvidenceSource.h"


@interface SleepEvidenceSource : GenericEvidenceSource {
	BOOL systemGoingToSleep;
	BOOL systemWakingUp;
}

- (id) init;

- (void) doRealUpdate;

- (void) start;
- (void) stop;

- (NSString*) name;
- (BOOL) doesRuleMatch: (NSDictionary*) rule;
- (NSString*) getSuggestionLeadText: (NSString*) type;
- (NSArray*) getSuggestions;

- (void) goingToSleep: (NSNotification*) note;
- (void) wakeFromSleep: (NSNotification*) note;
- (void) wakeFinished;

@end
