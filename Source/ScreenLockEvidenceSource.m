//
//  ScreenLockEvidenceSource.m
//  ControlPlane
//
//  Created by Roman Shevtsov on 12/12/15.
//
//

#import "DSLogger.h"
#import "ScreenLockEvidenceSource.h"

@implementation ScreenLockEvidenceSource

- (id) init {
    if (!(self = [super init]))
        return nil;
    
    return self;
}

- (NSString *) description {
    return NSLocalizedString(@"Create rules that are true when the system screen is locked or unlocked.", @"");
}

- (void) doRealUpdate {
    [self setDataCollected:YES];
}

- (NSString*) name {
    return @"ScreenLock";
}

- (BOOL) doesRuleMatch: (NSDictionary*) rule {
    NSString *param = [rule objectForKey:@"parameter"];
    
    return (([param isEqualToString: @"lock"] && screenIsLocked) ||
            ([param isEqualToString: @"unlock"] && !screenIsLocked));
}

- (NSString*) getSuggestionLeadText: (NSString*) type {
    return NSLocalizedString(@"Screen lock is", @"In rule-adding dialog");
}

- (NSArray*) getSuggestions {
    return [NSArray arrayWithObjects:
            [NSDictionary dictionaryWithObjectsAndKeys:
             @"ScreenLock", @"type", @"lock", @"parameter",
             NSLocalizedString(@"Locked", @""), @"description", nil],
            [NSDictionary dictionaryWithObjectsAndKeys:
             @"ScreenLock", @"type", @"unlock", @"parameter",
             NSLocalizedString(@"Unlocked", @""), @"description", nil],
            nil];
}

- (void) start {
    if (running)
        return;
    
    [self doRealUpdate];
    
    running = YES;
}

- (void) stop {
    if (!running)
        return;
    
    [self setDataCollected:NO];
    
    running = NO;
}

- (NSString *) friendlyName {
    return NSLocalizedString(@"Screen Lock/Unlock", @"");
}

- (void) screenDidUnlock:(NSNotification *)notification {
    #ifdef DEBUG_MODE
        DSLog(@"screenDidUnlock: %@", [notification name]);
    #endif

    [super screenDidUnlock:nil];
    [self doRealUpdate];
}

- (void) screenDidLock:(NSNotification *)notification {
    #ifdef DEBUG_MODE
        DSLog(@"screenDidLock: %@", [notification name]);
    #endif

    [super screenDidLock:nil];
    [self doRealUpdate];
}

@end
