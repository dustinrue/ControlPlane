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
#import "SysConf.h"

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
	[appDefaults setValue:[NSNumber numberWithBool:NO] forKey:@"EnableBluetoothEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnableFireWireEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnableIPEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnableMonitorEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnablePowerEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnableRunningApplicationEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnableUSBEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnableWiFiEvidenceSource"];

	[appDefaults setValue:[NSNumber numberWithBool:NO] forKey:@"UseDefaultLocation"];
	[appDefaults setValue:@"Automatic" forKey:@"DefaultLocation"];

	[appDefaults setValue:[NSNumber numberWithBool:NO] forKey:@"ShowAdvancedPreferences"];
	[appDefaults setValue:[NSNumber numberWithFloat:5.0] forKey:@"UpdateInterval"];
	[appDefaults setValue:[NSNumber numberWithBool:NO] forKey:@"WiFiAlwaysScans"];

	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"SUCheckAtStartup"];	// SparkleUpdater

	[[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
}

// Helper: Load a named image, and scale it to be suitable for menu bar use.
- (NSImage *)prepareImageForMenubar:(NSString *)name
{
	NSImage *img = [NSImage imageNamed:name];
	[img setScalesWhenResized:YES];
	[img setSize:NSSizeFromString(@"{18,18}")];

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
	[self setValue:@"?" forKey:@"guessedLocation"];
	[self setValue:@"?" forKey:@"guessedConfidence"];

	return self;
}

- (void)dealloc
{
	[updatingSwitchingLock dealloc];
	[updatingLock dealloc];

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

	// Fill in 'Force location' submenu
	NSMenu *submenu = [[[NSMenu alloc] init] autorelease];
	NSEnumerator *en = [[SysConf locationsEnumerate] objectEnumerator];
	NSString *location;
	while ((location = [en nextObject])) {
		NSMenuItem *item = [[[NSMenuItem alloc] init] autorelease];
		[item setTitle:location];
		[item setRepresentedObject:location];
		[item setTarget:self];
		[item setAction:@selector(forceSwitch:)];
		[submenu addItem:item];
	}
	//[submenu addItem:[NSMenuItem separatorItem]];
	[forceLocationMenuItem setSubmenu:submenu];

	// Set up status bar.
	[self showInStatusBar:self];

	[NSThread detachNewThreadSelector:@selector(updateThread:)
				 toTarget:self
			       withObject:nil];

	// Start up evidence sources
	[evidenceSources startAll];

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

- (void)triggerDepartureActions:(NSString *)fromLocation
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
		if (![[action objectForKey:@"location"] isEqualToString:fromLocation])
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

	// Finally, we have to sleep this thread, so we don't return until we're ready to change locations.
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:max_delay]];
}

- (void)triggerArrivalActions:(NSString *)toLocation
{
	NSArray *actions = [actionsController arrangedObjects];

	NSEnumerator *action_enum = [actions objectEnumerator];
	NSDictionary *action;
	while (action = [action_enum nextObject]) {
		if (![[action objectForKey:@"when"] isEqualToString:@"Arrival"])
			continue;
		if (![[action objectForKey:@"location"] isEqualToString:toLocation])
			continue;
		[NSThread detachNewThreadSelector:@selector(executeAction:) toTarget:self withObject:action];
	}
}

#pragma mark Thread stuff

- (void)performTransitionFrom:(NSString *)fromLocation to:(NSString *)toLocation
{
#ifdef DEBUG_MODE
	NSLog(@"About to change to location '%@' %@.\n", toLocation, guessedConfidence);
#endif
	[updatingSwitchingLock lock];

	// Execute "Departure" actions
	[self triggerDepartureActions:fromLocation];

	[self doGrowl:NSLocalizedString(@"Changing Location", @"Growl message title")
	  withMessage:[NSString stringWithFormat:NSLocalizedString(@"Changing to location '%@' %@.",
								   @"First parameter is the location name, second parameter is the confidence value, or 'as default location'"),
			toLocation, guessedConfidence]];
	if (![SysConf setCurrentLocation:toLocation]) {
		[self doGrowl:NSLocalizedString(@"Failure", @"Growl message title")
		  withMessage:NSLocalizedString(@"Changing location failed!", @"")];
		[updatingSwitchingLock unlock];
		return;
	}

	// Execute "Arrival" actions
	[self triggerArrivalActions:toLocation];

	[updatingSwitchingLock unlock];
}

- (void)forceSwitch:(id)sender
{
	NSString *location = [sender representedObject];
#ifdef DEBUG_MODE
	NSLog(@"forceSwitch: going to '%@'", location);
#endif
	[self setValue:location forKey:@"guessedLocation"];
	[self setValue:NSLocalizedString(@"(forced)", @"Used when force-switching to a location")
		forKey:@"guessedConfidence"];
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowGuess"])
		[self setStatusTitle:location];

	[self performTransitionFrom:[SysConf getCurrentLocation] to:location];
}

- (void)doUpdateForReal
{
	NSArray *locations = [SysConf locationsEnumerate];

	// Maps a guessed location name to an "unconfidence" value, which is
	// equal to (1 - confidence). We step through all the rules that are "hits",
	// and multiply this running unconfidence value by (1 - rule.confidence).
	NSMutableDictionary *guesses = [NSMutableDictionary dictionaryWithCapacity:[locations count]];
	NSArray *rule_hits = [self getRulesThatMatch];

	NSEnumerator *en = [rule_hits objectEnumerator];
	NSDictionary *rule;
	while (rule = [en nextObject]) {
		NSString *loc = [rule objectForKey:@"location"];

		NSNumber *uncon = [guesses objectForKey:loc];
		if (!uncon)
			uncon = [NSNumber numberWithDouble:1.0];
		NSNumber *mult = [rule objectForKey:@"confidence"];
		uncon = [NSNumber numberWithDouble:[uncon doubleValue] * (1 - [mult doubleValue])];
		[guesses setObject:uncon forKey:loc];

#ifdef DEBUG_MODE
//		NSLog(@"* Rule Matches: type=%@, parameter=%@, location=%@, confidence=%@, description=%@\n",
//		      [rule objectForKey:@"type"], [rule objectForKey:@"parameter"],
//		      [rule objectForKey:@"location"], [rule objectForKey:@"confidence"],
//		      [rule objectForKey:@"description"]);
#endif
	}

	// Guess location with lowest unconfidence
	en = [guesses keyEnumerator];
	NSString *loc, *guess = nil;
	double guessConfidence = 0.0;
	while (loc = [en nextObject]) {
		double uncon = [[guesses objectForKey:loc] doubleValue];
		if (((1.0 - uncon) > guessConfidence) || !guess) {
			guess = loc;
			guessConfidence = 1.0 - uncon;
		}
	}

	//---------------------------------------------------------------
	NSNumberFormatter *nf = [[[NSNumberFormatter alloc] init] autorelease];
	[nf setFormatterBehavior:NSNumberFormatterBehavior10_4];
	[nf setNumberStyle:NSNumberFormatterPercentStyle];
	NSString *perc = [nf stringFromNumber:[NSDecimalNumber numberWithDouble:guessConfidence]];
	NSString *guessConfidenceString = [NSString stringWithFormat:
		NSLocalizedString(@"with confidence %@", @"Appended to a location-change notification"),
		perc];
	BOOL do_title = [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowGuess"];
	if (!do_title)
		[self setStatusTitle:nil];

	BOOL no_guess = NO;
	if (!guess) {
#ifdef DEBUG_MODE
		NSLog(@"No guess made.\n");
#endif
		no_guess = YES;
	} else if (guessConfidence < [[NSUserDefaults standardUserDefaults] floatForKey:@"MinimumConfidenceRequired"]) {
#ifdef DEBUG_MODE
		NSLog(@"Guess of '%@' isn't confident enough: only %@.\n", guess, guessConfidenceString);
#endif
		no_guess = YES;
	}

	if (no_guess) {
		if (![[NSUserDefaults standardUserDefaults] boolForKey:@"UseDefaultLocation"]) {
			if (do_title)
				[self setStatusTitle:@"?"];
			return;
		}
		guess = [[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultLocation"];
		guessConfidenceString = NSLocalizedString(@"as default location",
							  @"Appended to a location-change notification");
	}

	BOOL do_switch = YES;

	BOOL smoothing = [[NSUserDefaults standardUserDefaults] boolForKey:@"EnableSwitchSmoothing"];
	if (smoothing && ![guessedLocation isEqualToString:guess]) {
		do_switch = NO;
#ifdef DEBUG_MODE
		NSLog(@"Switch smoothing kicking in... (%@ != %@)", guessedLocation, guess);
#endif
	}

	if (do_title)
		[self setStatusTitle:guess];
	[self setValue:guess forKey:@"guessedLocation"];
	[self setValue:guessConfidenceString forKey:@"guessedConfidence"];

	if (!do_switch)
		return;

	if ([guess isEqualToString:[SysConf getCurrentLocation]]) {
#ifdef DEBUG_MODE
		NSLog(@"Guessed '%@' (%@); already there.\n", guess, guessConfidenceString);
#endif
		return;
	}

	[self performTransitionFrom:[SysConf getCurrentLocation] to:guess];
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

#pragma mark Growl delegates

- (NSDictionary *) registrationDictionaryForGrowl
{
	NSArray *notifications = [NSArray arrayWithObjects:
					NSLocalizedString(@"Changing Location", @"Growl message title"),
					NSLocalizedString(@"Performing Action", @"Growl message title"),
					NSLocalizedString(@"Failure", @"Growl message title"),
					NSLocalizedString(@"Evidence Change", @"Growl message title"),
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

@end
