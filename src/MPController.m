//
//  MPController.m
//  MarcoPolo
//
//  Created by David Symonds on 1/02/07.
//

#include "Growl/GrowlApplicationBridge.h"

#import "Action.h"
#import "ContextsDataSource.h"
#import "EvidenceSource.h"
#import "MPController.h"

#import "NetworkLocationAction.h"



@implementation MPController

#define STATUS_BAR_LINGER	10	// seconds before disappearing from menu bar



+ (void)initialize
{
	NSMutableDictionary *appDefaults = [NSMutableDictionary dictionary];

	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"Enabled"];
	[appDefaults setValue:[NSNumber numberWithDouble:0.75] forKey:@"MinimumConfidenceRequired"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"ShowGuess"];
	[appDefaults setValue:[NSNumber numberWithBool:NO] forKey:@"EnableSwitchSmoothing"];
	[appDefaults setValue:[NSNumber numberWithBool:NO] forKey:@"HideStatusBarIcon"];

	// TODO: spin these into the EvidenceSourceSetController?
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnableAudioOutputEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:NO] forKey:@"EnableBluetoothEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnableFireWireEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnableIPEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnableMonitorEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnablePowerEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnableRunningApplicationEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnableUSBEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnableWiFiEvidenceSource"];

	[appDefaults setValue:[NSNumber numberWithBool:NO] forKey:@"UseDefaultContext"];
	[appDefaults setValue:@"Automatic" forKey:@"DefaultContext"];

	// Advanced
	[appDefaults setValue:[NSNumber numberWithBool:NO] forKey:@"ShowAdvancedPreferences"];
	[appDefaults setValue:[NSNumber numberWithFloat:5.0] forKey:@"UpdateInterval"];
	[appDefaults setValue:[NSNumber numberWithBool:NO] forKey:@"WiFiAlwaysScans"];

	// Sparkle (TODO: make update time configurable?)
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"SUCheckAtStartup"];

	[[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
}

// Helper: Load a named image, and scale it to be suitable for menu bar use.
- (NSImage *)prepareImageForMenubar:(NSString *)name
{
	NSImage *img = [NSImage imageNamed:name];
	[img setScalesWhenResized:YES];
	[img setSize:NSMakeSize(18, 18)];

	return img;
}

- (id)init
{
	if (!(self = [super init]))
		return nil;

	// Growl registration
	[GrowlApplicationBridge setGrowlDelegate:self];

	sbImage = [self prepareImageForMenubar:@"mp-icon"];
	sbItem = nil;
	sbHideTimer = nil;

	updatingSwitchingLock = [[NSLock alloc] init];
	updatingLock = [[NSConditionLock alloc] initWithCondition:0];
	timeToDie = FALSE;

	// Set placeholder values
	[self setValue:@"" forKey:@"currentContextUUID"];
	[self setValue:@"?" forKey:@"currentContextName"];
	[self setValue:@"?" forKey:@"guessConfidence"];

	return self;
}

- (void)dealloc
{
	[updatingSwitchingLock release];
	[updatingLock release];

	[super dealloc];
}

- (void)awakeFromNib
{
	// If there aren't any contexts defined, populate list from network locations
	if ([[[NSUserDefaults standardUserDefaults] arrayForKey:@"Contexts"] count] == 0) {
		NSEnumerator *en = [[NetworkLocationAction limitedOptions] objectEnumerator];
		NSDictionary *dict;
		while ((dict = [en nextObject])) {
			[contextsDataSource newContextWithName:[dict valueForKey:@"option"]];
		}
	}

	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(contextsChanged:)
						     name:@"ContextsChangedNotification"
						   object:contextsDataSource];
	[self contextsChanged:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(userDefaultsChanged:)
						     name:@"NSUserDefaultsDidChangeNotification"
						   object:nil];

	// Set up status bar.
	[self showInStatusBar:self];

	[NSThread detachNewThreadSelector:@selector(updateThread:)
				 toTarget:self
			       withObject:nil];

	// Start up evidence sources that should be started
	[evidenceSources startOrStopAll];

	// Schedule a one-off timer (in 2s) to get initial data.
	// Future recurring timers will be set automatically from there.
	[NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)2
					 target:self
				       selector:@selector(doUpdate:)
				       userInfo:nil
					repeats:NO];

	[NSApp unhide];
}

- (void)setStatusTitle:(NSString *)title
{
	if (!sbItem)
		return;
	if (!title) {
		[sbItem setTitle:nil];
		return;
	}

	// Smaller font
	NSFont *font = [NSFont menuBarFontOfSize:10.0];
	NSDictionary *attrs = [NSDictionary dictionaryWithObject:font
							  forKey:NSFontAttributeName];
	NSAttributedString *as = [[NSAttributedString alloc] initWithString:title attributes:attrs];
	[sbItem setAttributedTitle:[as autorelease]];
}

- (void)showInStatusBar:(id)sender
{
	if (sbItem) {
		// Already there? Rebuild it anyway.
		[[NSStatusBar systemStatusBar] removeStatusItem:sbItem];
		[sbItem release];
	}

	sbItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
	[sbItem retain];
	[sbItem setHighlightMode:YES];
	[sbItem setImage:sbImage];
	[sbItem setMenu:sbMenu];
}

- (void)hideFromStatusBar:(NSTimer *)theTimer
{
	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"HideStatusBarIcon"])
		return;

	[[NSStatusBar systemStatusBar] removeStatusItem:sbItem];
	[sbItem release];
	sbItem = nil;
	sbHideTimer = nil;
}

- (void)doGrowl:(NSString *)title withMessage:(NSString *)message
{
	float pri = 0;

	if ([title isEqualToString:@"Failure"])
		pri = 1;

	[GrowlApplicationBridge notifyWithTitle:title
				    description:message
			       notificationName:title
				       iconData:nil
				       priority:pri
				       isSticky:NO
				   clickContext:nil];
}

- (void)contextsChanged:(NSNotification *)notification
{
	// Fill in 'Force context' submenu
	NSMenu *submenu = [[[NSMenu alloc] init] autorelease];
	NSEnumerator *en = [[contextsDataSource orderedTraversal] objectEnumerator];
	Context *ctxt;
	while ((ctxt = [en nextObject])) {
		NSMenuItem *item = [[[NSMenuItem alloc] init] autorelease];
		[item setTitle:[ctxt name]];
		[item setIndentationLevel:[[ctxt valueForKey:@"depth"] intValue]];
		[item setRepresentedObject:ctxt];
		[item setTarget:self];
		[item setAction:@selector(forceSwitch:)];
		[submenu addItem:item];
	}
	[forceContextMenuItem setSubmenu:submenu];

	// Update current context details
	ctxt = [contextsDataSource contextByUUID:currentContextUUID];
	if (ctxt) {
		[self setValue:[ctxt name] forKey:@"currentContextName"];
	} else {
		// Our current context was removed
		[self setValue:@"" forKey:@"currentContextUUID"];
		[self setValue:@"?" forKey:@"currentContextName"];
		[self setValue:@"?" forKey:@"guessConfidence"];
	}
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowGuess"])
		[self setStatusTitle:currentContextName];

	// TODO: update other stuff?
}

#pragma mark Rule matching and Action triggering

- (void)doUpdate:(NSTimer *)theTimer
{
	// Check timer interval
	NSTimeInterval intv = [[NSUserDefaults standardUserDefaults] floatForKey:@"UpdateInterval"];
	if (fabs(intv - [theTimer timeInterval]) > 0.1) {
		if ([theTimer isValid])
			[theTimer invalidate];
		[NSTimer scheduledTimerWithTimeInterval:intv
						 target:self
					       selector:@selector(doUpdate:)
					       userInfo:nil
						repeats:YES];
	}

	// Check status bar visibility
	BOOL hide = [[NSUserDefaults standardUserDefaults] boolForKey:@"HideStatusBarIcon"];
	if (sbItem && hide && !sbHideTimer)
		sbHideTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)STATUS_BAR_LINGER
						 target:self
					       selector:@selector(hideFromStatusBar:)
					       userInfo:nil
						repeats:NO];
	else if (!hide && sbHideTimer) {
		[sbHideTimer invalidate];
		sbHideTimer = nil;
	}
	if (!hide && !sbItem)
		[self showInStatusBar:self];

	[updatingLock lock];
	//[sbItem setImage:imageActive];
	[updatingLock unlockWithCondition:1];
}

- (NSArray *)getRulesThatMatch
{
	NSArray *rules = [rulesController arrangedObjects];
	NSMutableArray *matching_rules = [NSMutableArray array];

	NSEnumerator *rule_enum = [rules objectEnumerator];
	NSDictionary *rule;
	while (rule = [rule_enum nextObject]) {
		if ([evidenceSources ruleMatches:rule])
			[matching_rules addObject:rule];
	}

	return matching_rules;
}

- (void)executeAction:(id)arg
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSDictionary *action_dict = (NSDictionary *) arg;

	NSNumber *delay;
	if ((delay = [action_dict valueForKey:@"delay"]))
		[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:[delay intValue]]];

	Action *action = [Action actionFromDictionary:action_dict];
	if (!action) {
		[self doGrowl:NSLocalizedString(@"Performing Action", @"Growl message title")
		  withMessage:[NSString stringWithFormat:@"ERROR: Unknown type '%@', parameter='%@'",
				[action_dict valueForKey:@"type"], [action_dict objectForKey:@"parameter"]]];
		[pool release];
		return;
	}

	[self doGrowl:NSLocalizedString(@"Performing Action", @"Growl message title")
	  withMessage:[action description]];

	NSString *errorString;
	if (![action execute:&errorString])
		[self doGrowl:NSLocalizedString(@"Failure", @"Growl message title")
		  withMessage:errorString];

	[pool release];
}

- (void)triggerDepartureActions:(NSString *)fromUUID
{
	NSArray *actions = [actionsController arrangedObjects];
	NSMutableArray *actionsToRun = [NSMutableArray array];
	int max_delay = 0;

	// This is slightly trickier than triggerArrivalActions, since the "delay" value is
	// a reverse delay, rather than a forward delay. We scan through the actions, finding
	// all the ones that need to be run, calculating the maximum delay along the way.
	// We then go through those selected actions, and run a surrogate action for each with
	// a delay equal to (max_delay - original_delay).

	NSEnumerator *action_enum = [actions objectEnumerator];
	NSDictionary *action;
	while ((action = [action_enum nextObject])) {
		if (![[action objectForKey:@"when"] isEqualToString:@"Departure"])
			continue;
		if (![[action objectForKey:@"context"] isEqualToString:fromUUID])
			continue;

		NSNumber *aDelay;
		if ((aDelay = [action valueForKey:@"delay"])) {
			if ([aDelay intValue] > max_delay)
				max_delay = [aDelay intValue];
		}

		[actionsToRun addObject:action];

	}

	action_enum = [actionsToRun objectEnumerator];
	while ((action = [action_enum nextObject])) {
		NSMutableDictionary *surrogateAction = [NSMutableDictionary dictionaryWithDictionary:action];
		int original_delay = [[action valueForKey:@"delay"] intValue];
		[surrogateAction setValue:[NSNumber numberWithInt:(max_delay - original_delay)]
				   forKey:@"delay"];
		[NSThread detachNewThreadSelector:@selector(executeAction:)
					 toTarget:self
				       withObject:surrogateAction];
	}

	// Finally, we have to sleep this thread, so we don't return until we're ready to change contexts.
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:max_delay]];
}

- (void)triggerArrivalActions:(NSString *)toUUID
{
	NSArray *actions = [actionsController arrangedObjects];

	NSEnumerator *action_enum = [actions objectEnumerator];
	NSDictionary *action;
	while (action = [action_enum nextObject]) {
		if (![[action objectForKey:@"when"] isEqualToString:@"Arrival"])
			continue;
		if (![[action objectForKey:@"context"] isEqualToString:toUUID])
			continue;
		[NSThread detachNewThreadSelector:@selector(executeAction:) toTarget:self withObject:action];
	}
}

#pragma mark Thread stuff

- (void)performTransitionFrom:(NSString *)fromUUID to:(NSString *)toUUID
{
	NSArray *walks = [contextsDataSource walkFrom:fromUUID to:toUUID];
	NSArray *leaving_walk = [walks objectAtIndex:0];
	NSArray *entering_walk = [walks objectAtIndex:1];
	NSEnumerator *en;
	Context *ctxt;

	[updatingSwitchingLock lock];

	// Execute all the "Departure" actions
	en = [leaving_walk objectEnumerator];
	while ((ctxt = [en nextObject])) {
#ifdef DEBUG_MODE
		NSLog(@">> Depart from '%@'", [ctxt name]);
#endif
		[self triggerDepartureActions:[ctxt uuid]];
	}

	// Update current context
	[self setValue:toUUID forKey:@"currentContextUUID"];
	ctxt = [contextsDataSource contextByUUID:toUUID];
	[self setValue:[ctxt name] forKey:@"currentContextName"];
	[self doGrowl:NSLocalizedString(@"Changing Context", @"Growl message title")
	  withMessage:[NSString stringWithFormat:NSLocalizedString(@"Changing to context '%@' %@.",
								   @"First parameter is the context name, second parameter is the confidence value, or 'as default context'"),
			currentContextName, guessConfidence]];

	// Execute all the "Arrival" actions
	en = [entering_walk objectEnumerator];
	while ((ctxt = [en nextObject])) {
#ifdef DEBUG_MODE
		NSLog(@">> Arrive at '%@'", [ctxt name]);
#endif
		[self triggerArrivalActions:[ctxt uuid]];
	}
	
	[updatingSwitchingLock unlock];

	return;
}

- (void)forceSwitch:(id)sender
{
	Context *ctxt = [sender representedObject];
#ifdef DEBUG_MODE
	NSLog(@"forceSwitch: going to '%@'", [ctxt name]);
#endif
	[self setValue:NSLocalizedString(@"(forced)", @"Used when force-switching to a context")
		forKey:@"guessConfidence"];
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowGuess"])
		[self setStatusTitle:[ctxt name]];

	[self performTransitionFrom:currentContextUUID to:[ctxt uuid]];
}

- (void)doUpdateForReal
{
	NSArray *contexts = [contextsDataSource arrayOfUUIDs];

	// Maps a guessed context to an "unconfidence" value, which is
	// equal to (1 - confidence). We step through all the rules that are "hits",
	// and multiply this running unconfidence value by (1 - rule.confidence).
	NSMutableDictionary *guesses = [NSMutableDictionary dictionaryWithCapacity:[contexts count]];
	NSArray *rule_hits = [self getRulesThatMatch];

	NSEnumerator *en = [rule_hits objectEnumerator];
	NSDictionary *rule;
	while (rule = [en nextObject]) {
		NSString *uuid = [rule objectForKey:@"context"];

		NSNumber *uncon = [guesses objectForKey:uuid];
		if (!uncon)
			uncon = [NSNumber numberWithDouble:1.0];
		NSNumber *mult = [rule objectForKey:@"confidence"];
		uncon = [NSNumber numberWithDouble:[uncon doubleValue] * (1 - [mult doubleValue])];
		[guesses setObject:uncon forKey:uuid];
	}

	// TODO: With nested contexts, perhaps we should credit a decaying value for matched rules
	// to the ancestor walk?

	// Guess context with lowest unconfidence
	en = [guesses keyEnumerator];
	NSString *uuid, *guess = nil;
	double guessConf = 0.0;
	while ((uuid = [en nextObject])) {
		double uncon = [[guesses objectForKey:uuid] doubleValue];
		if (((1.0 - uncon) > guessConf) || !guess) {
			guess = uuid;
			guessConf = 1.0 - uncon;
		}
	}

	//---------------------------------------------------------------
	NSNumberFormatter *nf = [[[NSNumberFormatter alloc] init] autorelease];
	[nf setFormatterBehavior:NSNumberFormatterBehavior10_4];
	[nf setNumberStyle:NSNumberFormatterPercentStyle];
	NSString *perc = [nf stringFromNumber:[NSDecimalNumber numberWithDouble:guessConf]];
	NSString *guessConfidenceString = [NSString stringWithFormat:
		NSLocalizedString(@"with confidence %@", @"Appended to a context-change notification"),
		perc];
	BOOL do_title = [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowGuess"];
	if (!do_title)
		[self setStatusTitle:nil];
	NSString *guessString = [[contextsDataSource contextByUUID:guess] name];

	BOOL no_guess = NO;
	if (!guess) {
#ifdef DEBUG_MODE
		NSLog(@"No guess made.\n");
#endif
		no_guess = YES;
	} else if (guessConf < [[NSUserDefaults standardUserDefaults] floatForKey:@"MinimumConfidenceRequired"]) {
#ifdef DEBUG_MODE
		NSLog(@"Guess of '%@' isn't confident enough: only %@.\n", guessString, guessConfidenceString);
#endif
		no_guess = YES;
	}

	if (no_guess) {
		if (![[NSUserDefaults standardUserDefaults] boolForKey:@"UseDefaultContext"]) {
			if (do_title)
				[self setStatusTitle:@"?"];
			return;
		}
		guess = [[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultContext"];
		guessConfidenceString = NSLocalizedString(@"as default context",
							  @"Appended to a context-change notification");
		guessString = [[contextsDataSource contextByUUID:guess] name];
	}

	BOOL do_switch = YES;

	BOOL smoothing = [[NSUserDefaults standardUserDefaults] boolForKey:@"EnableSwitchSmoothing"];
	if (smoothing && ![currentContextUUID isEqualToString:guess]) {
		do_switch = NO;
#ifdef DEBUG_MODE
		NSLog(@"Switch smoothing kicking in... (%@ != %@)", currentContextName, guessString);
#endif
	}

	if (do_title)
		[self setStatusTitle:guessString];
	[self setValue:guessConfidenceString forKey:@"guessConfidence"];

	if (!do_switch)
		return;

	if ([guess isEqualToString:currentContextUUID]) {
#ifdef DEBUG_MODE
		NSLog(@"Guessed '%@' (%@); already there.\n", guessString, guessConfidenceString);
#endif
		return;
	}

	[self performTransitionFrom:currentContextUUID to:guess];
}

- (void)updateThread:(id)arg
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	while (!timeToDie) {
		[updatingLock lockWhenCondition:1];

		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Enabled"]) {
			[self doUpdateForReal];

			// Flush auto-release pool
			[pool release];
			pool = [[NSAutoreleasePool alloc] init];
		}

//end_of_update:
		//[sbItem setImage:imageIdle];
		[updatingLock unlockWithCondition:0];
	}

	[pool release];
}

#pragma mark UI helpers

- (unsigned int)pushSuggestionsFromSource:(NSString *)name ofType:(NSString *)type intoController:(NSArrayController *)controller
{
	NSArray *suggestions = [evidenceSources getSuggestionsFromSource:name ofType:type];

	[controller removeObjects:[controller arrangedObjects]];
	[controller addObjects:suggestions];
	[controller selectNext:self];

	return [suggestions count];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark -
#pragma mark Growl delegates

- (NSDictionary *) registrationDictionaryForGrowl
{
	NSArray *notifications = [NSArray arrayWithObjects:
					NSLocalizedString(@"Changing Context", @"Growl message title"),
					NSLocalizedString(@"Performing Action", @"Growl message title"),
					NSLocalizedString(@"Failure", @"Growl message title"),
					//NSLocalizedString(@"Evidence Change", @"Growl message title"),
					nil];

	return [NSDictionary dictionaryWithObjectsAndKeys:
		notifications, GROWL_NOTIFICATIONS_ALL,
		notifications, GROWL_NOTIFICATIONS_ALL,
		nil];
}

- (NSString *) applicationNameForGrowl
{
	return @"MarcoPolo";
}

#pragma mark NSApplication delegates

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
	// Set up status bar.
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"HideStatusBarIcon"]) {
		[self showInStatusBar:self];
		sbHideTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)STATUS_BAR_LINGER
						 target:self
					       selector:@selector(hideFromStatusBar:)
					       userInfo:nil
						repeats:NO];
	}

	return YES;
}

#pragma mark NSUserDefaults notifications

- (void)userDefaultsChanged:(NSNotification *)notification
{
	// Check that the running evidence sources match the defaults
	[evidenceSources startOrStopAll];
}

@end
