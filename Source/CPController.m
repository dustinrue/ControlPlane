//
//  CPController.m
//  ControlPlane
//
//  Created by David Symonds on 1/02/07.
//

#import "Action.h"
#import "DSLogger.h"
#import "CPController.h"
#import "CPController+SleepThread.h"
#import "NetworkLocationAction.h"
#import "NSTimer+Invalidation.h"
#import "CPNotifications.h"
#import <libkern/OSAtomic.h>


@interface CPController (Private)

- (void)setStatusTitle:(NSString *)title;
- (void)showInStatusBar:(id)sender;
- (void)hideFromStatusBar:(NSTimer *)theTimer;
- (void)doHideFromStatusBar:(BOOL)forced;

- (void)postUserNotification:(NSString *)title withMessage:(NSString *)message;
- (void)contextsChanged:(NSNotification *)notification;

- (void)doUpdateByTimer:(NSTimer *)theTimer;
- (void)doUpdate;

- (void)updateThread:(id)arg;
- (void)goingToSleep:(id)arg;
- (void)wakeFromSleep:(id)arg;

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag;
- (void)applicationWillTerminate:(NSNotification *)aNotification;

- (void)userDefaultsChanged:(NSNotification *)notification;

- (void)importVersion1Settings;
- (void)importVersion1SettingsFinish: (BOOL)rulesImported withActions: (BOOL)actionsImported andIPActions: (BOOL)ipActionsFound;

- (void)forceSwitchAndToggleSticky:(id)sender;

- (void)setMenuBarImage:(NSImage *)imageName;

// ScreenSaver monitoring
- (void) setScreenSaverActive:(NSNotification *) notification;
- (void) setScreenSaverInActive:(NSNotification *) notification;

// Screen lock monitoring
- (void) setScreenLockActve:(NSNotification *) notification;
- (void) setScreenLockInActive:(NSNotification *) notification;

// Action Queue
- (void) addActionToQueue:(id) action;


// Evidence source monitoring
- (void) evidenceSourceDataDidChange:(NSNotification *) notification;

- (void) setStickyBit:(NSNotification *) notification;
- (void) unsetStickyBit:(NSNotification *) notification;

- (void) registerForNotifications;
- (NSMutableDictionary *)getGuesses;

@end

#pragma mark -

@interface CPController ()

@property (retain,atomic,readwrite) NSArray *rules;
@property (assign,atomic,readwrite) BOOL forceOneFullUpdate;

@end

@implementation CPController {
    NSNumberFormatter *numberFormatter;
}

#define STATUS_BAR_LINGER	10	// seconds before disappearing from menu bar
#define CP_DISPLAY_ICON     0
#define CP_DISPLAY_CONTEXT  1
#define CP_DISPLAY_BOTH     2

@synthesize screenSaverRunning;
@synthesize screenLocked;
@synthesize goingToSleep;

+ (NSMutableArray *)deepMutableCopyOfArray:(NSArray *)array {
    NSMutableArray *arrayMutableCopy = [NSMutableArray arrayWithCapacity:[array count]];
    for (id obj in array) {
        id objMutableCopy = [obj mutableCopy];
        [arrayMutableCopy addObject:objMutableCopy];
        [objMutableCopy release];
    }
    return arrayMutableCopy;
}

+ (void)initialize
{
	NSMutableDictionary *appDefaults = [NSMutableDictionary dictionary];

	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"Enabled"];
	[appDefaults setValue:[NSNumber numberWithDouble:0.75] forKey:@"MinimumConfidenceRequired"];
	[appDefaults setValue:[NSNumber numberWithBool:NO] forKey:@"EnableSwitchSmoothing"];
	[appDefaults setValue:[NSNumber numberWithBool:NO] forKey:@"HideStatusBarIcon"];
    [appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnableGrowl"];
    [appDefaults setValue:[NSNumber numberWithInt:CP_DISPLAY_ICON] forKey:@"menuBarOption"];

    
    // use CP_DISPLAY_BOTH if the option to ShowGuess is set to ensure compatiblity
    // with older preference setting
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowGuess"]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ShowGuess"];
        [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithInt:CP_DISPLAY_BOTH] forKey:@"menuBarOption"];
    }
	
	// TODO: spin these into the EvidenceSourceSetController?
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnableAudioOutputEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:NO] forKey:@"EnableBluetoothEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:NO] forKey:@"EnableDNSEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:NO] forKey:@"EnableFireWireEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnableIPEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:NO] forKey:@"EnableLightEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnableMonitorEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnablePowerEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnableRunningApplicationEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnableTimeOfDayEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnableUSBEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:NO] forKey:@"EnableCoreWLANEvidenceSource"];    
    [appDefaults setValue:[NSNumber numberWithBool:NO] forKey:@"SleepEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:NO] forKey:@"CoreLocationSource"];
	
	[appDefaults setValue:[NSNumber numberWithBool:NO] forKey:@"UseDefaultContext"];
	[appDefaults setValue:@"" forKey:@"DefaultContext"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnablePersistentContext"];
	[appDefaults setValue:@"" forKey:@"PersistentContext"];

	// Advanced
	[appDefaults setValue:[NSNumber numberWithBool:NO] forKey:@"ShowAdvancedPreferences"];
	[appDefaults setValue:[NSNumber numberWithFloat:5.0] forKey:@"UpdateInterval"];
	[appDefaults setValue:[NSNumber numberWithBool:NO] forKey:@"WiFiAlwaysScans"];

	// Debugging
	[appDefaults setValue:[NSNumber numberWithBool:NO] forKey:@"Debug OpenPrefsAtStartup"];
	[appDefaults setValue:[NSNumber numberWithBool:NO] forKey:@"Debug USBParanoia"];

	// Sparkle (TODO: make update time configurable?)
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"SUCheckAtStartup"];
    
    [appDefaults setValue:[NSNumber numberWithInt:1] forKey:@"SmoothSwitchCount"];

	[[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
    
}

// Helper: Load a named image, and scale it to be suitable for menu bar use.
- (NSImage *)prepareImageForMenubar:(NSString *)name
{
	NSImage *img = [NSImage imageNamed:name];
	[img setScalesWhenResized:YES];
    // TODO: provide images for retina displays
	[img setSize:NSMakeSize(18, 18)];

	return img;
}

- (id)init {
	if (!(self = [super init]))
		return nil;

	sbImageActive = [self prepareImageForMenubar:@"cp-icon-active"];
	sbImageInactive = [self prepareImageForMenubar:@"cp-icon-inactive"];
	sbItem = nil;
	sbHideTimer = nil;
	updatingTimer = nil;

	updatingSwitchingLock = [[NSLock alloc] init];
	updatingLock = [[NSConditionLock alloc] initWithCondition:0];
	timeToDie = FALSE;
	smoothCounter = 0;

	// Set placeholder values
	[self setValue:@"" forKey:@"currentContextUUID"];
	[self setValue:@"?" forKey:@"currentContextName"];
    
    [self setGoingToSleep:NO];

	forcedContextIsSticky = NO;

	numberFormatter = [[NSNumberFormatter alloc] init];
	[numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
	[numberFormatter setNumberStyle:NSNumberFormatterPercentStyle];

    NSArray *rulesInUserDefaults = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Rules"];
    _rules = [[[self class] deepMutableCopyOfArray:rulesInUserDefaults] retain];
    
    _forceOneFullUpdate = YES;
    
	return self;
}

- (void)dealloc {
    [_rules release];
    
    [numberFormatter release];
	[updatingSwitchingLock release];
	[updatingLock release];

	[super dealloc];
}

- (NSString *)currentContextName {
	return currentContextName;
}

- (ContextsDataSource *)contextsDataSource {
	return contextsDataSource;
}

- (NSArray *)activeRules {
    return [[self class] deepMutableCopyOfArray:self.rules];
}

- (void)setActiveRules:(NSArray *)newRules {
    NSMutableArray *rules = [[NSMutableArray alloc] initWithCapacity:[newRules count]];

    for (NSDictionary *ruleParams in newRules) {
        NSMutableDictionary *rule = [ruleParams mutableCopy];

        // remove all transient data
        [rule removeObjectForKey:@"status"];

        [rules addObject:rule];
        [rule release];
    }

    self.rules = rules; // atomic

    [[NSUserDefaults standardUserDefaults] setObject:rules forKey:@"Rules"];

    [rules release];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self doUpdate];
    });
}

- (BOOL) stickyContext {
	return forcedContextIsSticky;
}

- (void)importVersion1Settings {
	CFStringRef oldDomain = CFSTR("au.id.symonds.MarcoPolo");
	BOOL rulesImported = NO, actionsImported = NO;
	BOOL ipActionsFound = NO;
	Context *ctxt = nil;

	// Create contexts, populated from network locations
	NSEnumerator *en = [[NetworkLocationAction limitedOptions] objectEnumerator];
	NSDictionary *dict;
	NSMutableDictionary *lookup = [NSMutableDictionary dictionary];	// map location name -> (Context *)
	int cnt = 0;
	while ((dict = [en nextObject])) {
		ctxt = [contextsDataSource createContextWithName:[dict valueForKey:@"option"] fromUI:NO];
		[lookup setObject:ctxt forKey:[ctxt name]];
		++cnt;
	}
	NSLog(@"Quickstart: Created %d contexts", cnt);

	// Set "Automatic", or the first created context, as the default context
	if (!(ctxt = [lookup objectForKey:@"Automatic"]))
		ctxt = [contextsDataSource contextByUUID:[[contextsDataSource arrayOfUUIDs] objectAtIndex:0]];
	[[NSUserDefaults standardUserDefaults] setValue:[ctxt uuid] forKey:@"DefaultContext"];

	// See if there are old rules and actions to import
	NSArray *oldRules = (NSArray *) CFPreferencesCopyAppValue(CFSTR("Rules"), oldDomain);
	NSArray *oldActions = (NSArray *) CFPreferencesCopyAppValue(CFSTR("Actions"), oldDomain);
	if (!oldRules || !oldActions) {
		if (oldRules)
			CFRelease(oldRules);
		else if (oldActions)
			CFRelease(oldActions);
		
		[self importVersion1SettingsFinish:rulesImported withActions:actionsImported andIPActions:ipActionsFound];
		return;
	}
	
	[oldRules autorelease];
	[oldActions autorelease];

	// Replicate (some) rules
	NSMutableArray *newRules = [NSMutableArray array];
	en = [oldRules objectEnumerator];
	while ((dict = [en nextObject])) {
		if ([[dict valueForKey:@"type"] isEqualToString:@"IP"]) {
#if 1
			ipActionsFound = YES;
#else
			// Warn!
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			[alert setAlertStyle:NSWarningAlertStyle];
			[alert setMessageText:@"Couldn't import MarcoPolo 1.x IP rule"];
			[alert setInformativeText:
				[NSString stringWithFormat:@"A rule with description \"%@\" was not imported!",
					[dict valueForKey:@"description"]]];
			[alert runModal];
#endif
			continue;
		}

		NSMutableDictionary *rule = [NSMutableDictionary dictionaryWithDictionary:dict];
		ctxt = [lookup objectForKey:[rule valueForKey:@"location"]];
		if (ctxt)
			[rule setValue:[ctxt uuid] forKey:@"context"];
		[rule removeObjectForKey:@"location"];
		[newRules addObject:rule];
	}
	[[NSUserDefaults standardUserDefaults] setObject:newRules forKey:@"Rules"];
	NSLog(@"Quickstart: Imported %ld rules from MarcoPolo 1.x", (long) [newRules count]);
	rulesImported = YES;

	// Replicate actions
	NSMutableArray *newActions = [NSMutableArray array];
	en = [oldActions objectEnumerator];
	while ((dict = [en nextObject])) {
		NSMutableDictionary *action = [NSMutableDictionary dictionaryWithDictionary:dict];
		ctxt = [lookup objectForKey:[action valueForKey:@"location"]];
		if (ctxt)
			[action setValue:[ctxt uuid] forKey:@"context"];
		[action removeObjectForKey:@"location"];
		if ([[action valueForKey:@"parameter"] isEqual:@"on"])
			[action setValue:[NSNumber numberWithBool:YES] forKey:@"parameter"];
		else if ([[action valueForKey:@"parameter"] isEqual:@"off"])
				[action setValue:[NSNumber numberWithBool:NO] forKey:@"parameter"];
		[action setValue:[NSNumber numberWithBool:YES] forKey:@"enabled"];
		[newActions addObject:action];
	}
	[[NSUserDefaults standardUserDefaults] setObject:newActions forKey:@"Actions"];
	NSLog(@"Quickstart: Imported %ld actions from MarcoPolo 1.x", (long) [newActions count]);
	actionsImported = YES;

	// Create NetworkLocation actions
	newActions = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"Actions"]];
	en = [lookup objectEnumerator];
	cnt = 0;
	while ((ctxt = [en nextObject])) {
		Action *act = [[[NetworkLocationAction alloc] initWithOption:[ctxt name]] autorelease];
		NSMutableDictionary *act_dict = [act dictionary];
		[act_dict setValue:[ctxt uuid] forKey:@"context"];
		[act_dict setValue:NSLocalizedString(@"Set Network Location", @"") forKey:@"description"];
		[newActions addObject:act_dict];
		++cnt;
	}
	[[NSUserDefaults standardUserDefaults] setObject:newActions forKey:@"Actions"];
	NSLog(@"Quickstart: Created %d new NetworkLocation actions", cnt);
	
	[self importVersion1SettingsFinish:rulesImported withActions:actionsImported andIPActions:ipActionsFound];
}

- (void)importVersion1SettingsFinish: (BOOL)rulesImported withActions: (BOOL)actionsImported andIPActions: (BOOL)ipActionsFound {
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setAlertStyle:NSInformationalAlertStyle];
	if (!rulesImported && !actionsImported)
		[alert setMessageText:NSLocalizedString(@"Quick Start", @"")];
	else
		[alert setMessageText:NSLocalizedString(@"Quick Start and MarcoPolo 1.x Import", @"")];

	NSString *info = NSLocalizedString(@"Contexts have been made for you, named after your network locations.", @"");
	if (rulesImported) {
		if (!ipActionsFound)
			info = [info stringByAppendingFormat:@"\n\n%@",
				NSLocalizedString(@"All your rules have been imported.", @"")];
		else
			info = [info stringByAppendingFormat:@"\n\n%@",
				NSLocalizedString(@"All your rules (except IP rules) have been imported.", @"")];
	}
	if (actionsImported)
		info = [info stringByAppendingFormat:@"\n\n%@",
			NSLocalizedString(@"All your actions have been imported.", @"")];

	info = [info stringByAppendingFormat:@"\n\n%@",
		NSLocalizedString(@"We strongly recommend that you review your preferences.", @"")];

	[alert setInformativeText:info];

	[alert addButtonWithTitle:NSLocalizedString(@"OK", @"Button title")];
	[alert addButtonWithTitle:NSLocalizedString(@"Open Preferences", @"Button title")];
	[NSApp activateIgnoringOtherApps:YES];
	NSInteger rc = [alert runModal];
	if (rc == NSAlertSecondButtonReturn) {
		[NSApp activateIgnoringOtherApps:YES];
		[prefsWindow makeKeyAndOrderFront:self];
	}
}

/**
 * Copy over settings from the late MarcoPolo app, they should be compatible
 *
 * \return YES when settings have been imported
 */
- (BOOL) importMarcoPoloSettings {
	NSString *oldDomain = @"au.id.symonds.MarcoPolo2";
	NSDictionary *oldPrefs = [[NSUserDefaults standardUserDefaults] persistentDomainForName: oldDomain];
	
	if (oldPrefs) {
		DSLog(@"Importing settings from MarcoPolo 2.x");
		[[NSUserDefaults standardUserDefaults] setPersistentDomain: oldPrefs forName: [[NSBundle mainBundle] bundleIdentifier]];
		[[NSUserDefaults standardUserDefaults] removePersistentDomainForName: oldDomain];
		[[NSUserDefaults standardUserDefaults] synchronize];
		
		[contextsDataSource loadContexts];
		
	}
	
	return (oldPrefs ? YES : NO);
}

- (void)awakeFromNib {
#ifdef DEBUG_MODE
	NSLog(@"did super awake from nib");
#endif
    // Configures the crash reporter
    [[BWQuincyManager sharedQuincyManager] setSubmissionURL:[[[NSBundle mainBundle] infoDictionary] valueForKey:@"CPCrashReportURL"]];
    [[BWQuincyManager sharedQuincyManager] setCompanyName:@"ControlPlane developers"];
    [[BWQuincyManager sharedQuincyManager] setDelegate:self];
	
	// If there aren't any contexts defined, nor rules, nor actions, import settings
	if (([[[NSUserDefaults standardUserDefaults] arrayForKey:@"Contexts"] count] == 0) &&
	    ([[[NSUserDefaults standardUserDefaults] arrayForKey:@"Rules"] count] == 0) &&
	    ([[[NSUserDefaults standardUserDefaults] arrayForKey:@"Actions"] count] == 0)) {
		
		// first try importing from MarcoPolo 2.x
		if (![self importMarcoPoloSettings])
			// otherwise import from the old 1.x version
			[self importVersion1Settings];
	}

	// Persistent contexts
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"EnablePersistentContext"]) {
		NSString *uuid = [[NSUserDefaults standardUserDefaults] stringForKey:@"PersistentContext"];
		Context *ctxt = [contextsDataSource contextByUUID:uuid];
		if (ctxt) {
			[self setValue:uuid forKey:@"currentContextUUID"];
			[self setValue:[contextsDataSource pathFromRootTo:uuid] forKey:@"currentContextName"];

			// Update force context menu
			NSMenu *menu = [forceContextMenuItem submenu];
			for (NSMenuItem *item in [menu itemArray]) {
				NSString *rep = [item representedObject];
				if (rep && [contextsDataSource contextByUUID:rep]) {
                    BOOL ticked = ([rep isEqualToString:uuid]);
                    [item setState:(ticked ? NSOnState : NSOffState)];
                }
			}
		}
	}

    // set default screen saver and screen lock status
    [self setScreenLocked:NO];
    [self setScreenSaverRunning:NO];

    screensaverActionArrivalQueue = [[NSMutableArray arrayWithCapacity:0] retain];
    screensaverActionDepartureQueue = [[NSMutableArray arrayWithCapacity:0] retain];
    screenLockActionArrivalQueue = [[NSMutableArray arrayWithCapacity:0] retain];
    screenLockActionDepartureQueue = [[NSMutableArray arrayWithCapacity:0] retain];

    [self registerForNotifications];

	// update thread
	[NSThread detachNewThreadSelector:@selector(updateThread:)
							 toTarget:self
						   withObject:nil];

	// sleep thread
	[NSThread detachNewThreadSelector:@selector(monitorSleepThread:)
							 toTarget:self
						   withObject:nil];

    dispatch_async(dispatch_get_main_queue(), ^{
        // Start up evidence sources that should be started
        [evidenceSources startOrStopAll];

        if (!updatingTimer) {
            // Schedule a one-off timer (in 2s) to get initial data.
            // Future recurring timers will be set automatically from there.
            updatingTimer = [[NSTimer scheduledTimerWithTimeInterval: (NSTimeInterval)2
                                                              target: self
                                                            selector: @selector(doUpdateByTimer:)
                                                            userInfo: nil
                                                             repeats: NO] retain];
        }
    });

    dispatch_async(dispatch_get_main_queue(), ^{
        [self contextsChanged:nil];

        // Set up status bar.
        [self showInStatusBar:self];
        [self startOrStopHidingFromStatusBar];

        [NSApp unhideWithoutActivation];

        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Debug OpenPrefsAtStartup"]) {
            [NSApp activateIgnoringOtherApps:YES];
            [prefsWindow makeKeyAndOrderFront:self];
        }
    });
}


#pragma mark Register for notifications

- (void) registerForNotifications {
    // Register for notifications from evidence sources that their data has changed
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(evidenceSourceDataDidChange:)
                                                 name:@"evidenceSourceDataDidChange"
                                               object:nil];
    
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(contextsChanged:)
												 name:@"ContextsChangedNotification"
											   object:contextsDataSource];
    
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(userDefaultsChanged:)
												 name:NSUserDefaultsDidChangeNotification
											   object:nil];
    
	// Get notified when we go to sleep, and wake from sleep
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(goingToSleep:)
                                                 name:@"systemWillSleep"
                                               object:nil];
    
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(wakeFromSleep:)
                                                 name:@"systemDidWake"
                                               object:nil];
    
    // Monitor screensaver status
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(setScreenSaverInActive:)
                                                            name:@"com.apple.screensaver.didstop"
                                                          object:nil];
    
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(setScreenSaverActive:)
                                                            name:@"com.apple.screensaver.didstart"
                                                          object:nil];
    
    
    
    // Monitor screen lock status
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(setScreenLockActive:)
                                                            name:@"com.apple.screenIsLocked"
                                                          object:nil];
    
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(setScreenLockInActive:)
                                                            name:@"com.apple.screenIsUnlocked"
                                                          object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(setStickyBit:)
												 name:@"setStickyBit"
											   object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(unsetStickyBit:)
												 name:@"unsetStickyBit"
											   object:nil];
}


#pragma mark Menu Bar Wrangling


- (void)setStatusTitle:(NSString *)title {
	if (!sbItem) {
		return;
    }
	if (!title) {
		[sbItem setTitle:nil];
		return;
	}

	// Smaller font
	NSDictionary *attrs = @{ NSFontAttributeName: [NSFont menuBarFontOfSize:0] };
	NSAttributedString *as = [[NSAttributedString alloc] initWithString:title attributes:attrs];
	[sbItem setAttributedTitle:as];
    [as release];
}

- (void)updateMenuBarImage {
	if (!sbItem) {
		return;
    }

    NSImage *barImage = nil;
    if ([[NSUserDefaults standardUserDefaults] floatForKey:@"menuBarOption"] != CP_DISPLAY_CONTEXT) {
        barImage = ([currentContextUUID length] > 0) ? (sbImageActive) : (sbImageInactive);
    }

    [self setMenuBarImage:barImage];
}

- (void)setMenuBarImage:(NSImage *)imageName {
    // if the menu bar item has been hidden sbItem will have been released
    // and we should not attempt to update the image
    if (!sbItem) {
        return;
    }

    @try {
        [sbItem setImage:imageName];
    }
    @catch (NSException *exception) {
        DSLog(@"failed to set the menubar icon to %@ with error %@. Please alert ControlPlane Developers!", [imageName name], [exception reason]);
        [self setStatusTitle:@"Failed to set icon"];
    }
}

- (void)showInStatusBar:(id)sender {
	if (sbItem) {
		// Already there? Rebuild it anyway.
        [self doHideFromStatusBar:YES];
	}

	sbItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
	[sbItem setHighlightMode:YES];

    [self updateMenuBarImage];
    
    if ([[NSUserDefaults standardUserDefaults] floatForKey:@"menuBarOption"] != CP_DISPLAY_ICON) {
        [self setStatusTitle:currentContextName];
    }
	
	[sbItem setMenu:sbMenu];
}

- (void)hideFromStatusBar:(NSTimer *)theTimer {
    [self doHideFromStatusBar:NO];
}

- (void)doHideFromStatusBar:(BOOL)forced {
    if (sbHideTimer) {
        sbHideTimer = [sbHideTimer checkAndInvalidate];
    }
    
    if (forced || [[NSUserDefaults standardUserDefaults] boolForKey:@"HideStatusBarIcon"]) {
        if (sbItem) {
            [[NSStatusBar systemStatusBar] removeStatusItem:sbItem];
            [sbItem release];
            sbItem = nil;
        }
    }
}

- (void)startOrStopHidingFromStatusBar {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"HideStatusBarIcon"]) {
        if (!sbHideTimer && sbItem) {
            sbHideTimer = [[NSTimer scheduledTimerWithTimeInterval: (NSTimeInterval)STATUS_BAR_LINGER
                                                            target: self
                                                          selector: @selector(hideFromStatusBar:)
                                                          userInfo: nil
                                                           repeats: NO] retain];
        }
    } else {
		if (sbHideTimer) {
            sbHideTimer = [sbHideTimer checkAndInvalidate];
        }
        if (!sbItem) {
            [self showInStatusBar:self];
        }
    }
}

- (void)postUserNotification:(NSString *)title withMessage:(NSString *)message {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"EnableGrowl"]) {
        [CPNotifications postNotification:title withMessage:message];
    }
}

- (void)contextsChanged:(NSNotification *)notification {
#ifdef DEBUG_MODE
    DSLog(@"in contextChanged");
#endif
	// Fill in 'Force context' submenu
	NSMenu *submenu = [[[NSMenu alloc] init] autorelease];
	for (Context *ctxt in [contextsDataSource orderedTraversal]) {
		NSMenuItem *item = [[[NSMenuItem alloc] init] autorelease];
		[item setTitle:[ctxt name]];
		[item setIndentationLevel:[[ctxt valueForKey:@"depth"] intValue]];
		[item setRepresentedObject:[ctxt uuid]];
		[item setTarget:self];
		[item setAction:@selector(forceSwitch:)];
		[submenu addItem:item];

		item = [[item copy] autorelease];
		[item setTitle:[NSString stringWithFormat:@"%@ (*)", [item title]]];
		[item setKeyEquivalentModifierMask:NSAlternateKeyMask];
		[item setAlternate:YES];
		[item setAction:@selector(forceSwitchAndToggleSticky:)];
		[submenu addItem:item];
	}
	[submenu addItem:[NSMenuItem separatorItem]];
	{
		// Stick menu item
		NSMenuItem *item = [[[NSMenuItem alloc] init] autorelease];
		[item setTitle:NSLocalizedString(@"Stick forced contexts", @"")];
		[item setTarget:self];
		[item setAction:@selector(toggleSticky:)];
		// Binding won't work properly -- done correctly in forceSwitch:
//		[item bind:@"value" toObject:self withKeyPath:@"forcedContextIsSticky" options:nil];
		[item setState:(forcedContextIsSticky ? NSOnState : NSOffState)];
		[submenu addItem:item];
		stickForcedContextMenuItem = item;
	}
	[forceContextMenuItem setSubmenu:submenu];

	// Update current context details
	Context *ctxt = [contextsDataSource contextByUUID:currentContextUUID];
	if (ctxt) {
		[self setValue:[contextsDataSource pathFromRootTo:currentContextUUID] forKey:@"currentContextName"];
	} else {
		// Our current context was removed
		[self setValue:@""  forKey:@"currentContextUUID"];
		[self setValue:@"?" forKey:@"currentContextName"];
	}

    // Update menu bar (always do that in the main thread)
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateMenuBarImage];
        if ([[NSUserDefaults standardUserDefaults] floatForKey:@"menuBarOption"] != CP_DISPLAY_ICON) {
            [self setStatusTitle:currentContextName];
        }
    });

    self.forceOneFullUpdate = YES;

	// update other stuff?
}

#pragma mark Rule matching and Action triggering

- (void)doUpdateByTimer:(NSTimer *)theTimer {
#ifdef DEBUG_MODE
    DSLog(@"**** DOING UPDATE LOOP BY TIMER ****");
#endif
    [self doUpdate];
}

- (void)doUpdate {
    updatingTimer = [updatingTimer checkAndInvalidate];

    // cover any situations where there are queued items
    // but the screen is not locked and the screen saver is not running
    
    if (!screenLocked && (([screenLockActionArrivalQueue count] > 0) || ([screenLockActionDepartureQueue count] > 0))) {
        [self executeActionSet:screenLockActionDepartureQueue];
        [self executeActionSet:screenLockActionArrivalQueue];
    }
    
    if (!screenSaverRunning && (([screensaverActionArrivalQueue count] > 0) ||
                                ([screensaverActionDepartureQueue count] > 0))) {
        [self executeActionSet:screensaverActionDepartureQueue];
        [self executeActionSet:screensaverActionArrivalQueue];
    }

	// Check timer interval
	NSTimeInterval intv = [[NSUserDefaults standardUserDefaults] floatForKey:@"UpdateInterval"];
	if (intv > 0.1) {
		updatingTimer = [[NSTimer scheduledTimerWithTimeInterval: intv
														  target: self
														selector: @selector(doUpdateByTimer:)
														userInfo: nil
														 repeats: NO] retain];
	}
    
	[updatingLock lock];
	[updatingLock unlockWithCondition:1];
}

- (NSArray *)getRulesThatMatchAndSetChangeFlag:(BOOL *)flag {
	NSArray *rules = self.rules;
#ifdef DEBUG_MODE
    DSLog(@"number of rules %ld", [rules count]);
    DSLog(@"rules list %@", rules);
#endif
	NSMutableArray *matchingRules = [NSMutableArray array];
    BOOL changed = NO;

	for (NSMutableDictionary *rule in rules) {
#ifdef DEBUG_MODE
        DSLog(@"checking rule %@", rule);
#endif
		BOOL isMatching = [evidenceSources ruleMatches:rule];
        if (isMatching) {
			[matchingRules addObject:rule];
        }

        NSNumber *recentStatus = rule[@"status"];
        if (!recentStatus || ([recentStatus boolValue] != isMatching)) {
            rule[@"status"] = @(isMatching);
            changed = YES;
        }
	}

    if (changed) {
        *flag = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self willChangeValueForKey:@"activeRules"];
            [self didChangeValueForKey:@"activeRules"];
        });
    }

	return matchingRules;
}

// (Private) in a new thread, execute Action immediately, growling upon failure
// performs an individual action called by an executeAction* method and on
// a new thread
- (void)executeAction:(id)arg {
	@autoreleasepool {
        Action *action = (Action *) arg;
        
        NSString *errorString;
        if (![action execute:&errorString]) {
            [self postUserNotification:[[[NSString stringWithFormat:NSLocalizedString(@"Failure", @"Growl message title")] copy] autorelease] withMessage:[[errorString copy] autorelease]];
        }
        
        [self decreaseActionsInProgress];
    }
}

// (Private) in a new thread
// Parameter is an NSArray of actions; delay will be taken from the first one
- (void)executeActionSetWithDelay:(id)arg
{
	NSArray *actions = (NSArray *) arg;
	if ([actions count] == 0)
		return;

	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSTimeInterval delay = [[[actions objectAtIndex:0] valueForKey:@"delay"] doubleValue];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:delay]];

	// Aggregate growl messages
	NSString *growlTitle = NSLocalizedString(@"Performing Action", @"Growl message title");
	NSString *growlMessage = [[actions objectAtIndex:0] description];
	if ([actions count] > 1) {
		growlTitle = NSLocalizedString(@"Performing Actions", @"Growl message title");
		growlMessage = [NSString stringWithFormat:@"* %@", [actions componentsJoinedByString:@"\n* "]];
	}
	[self postUserNotification:[[growlTitle copy] autorelease] withMessage:[[growlMessage copy] autorelease]];

	for (Action *action in actions) {
		[self increaseActionsInProgress];
		[NSThread detachNewThreadSelector:@selector(executeAction:)
								 toTarget:self
							   withObject:action];
	}
	
	[self decreaseActionsInProgress];

	[pool release];
}

// (Private) This will group the growling together. The parameter should be an array of Action objects.
- (void)executeActionSet:(NSMutableArray *)actions
{
	if ([actions count] == 0)
		return;

	static double batchThreshold = 0.25;		// maximum grouping interval size

	// Sort by delay
	[actions sortUsingSelector:@selector(compareDelay:)];

	NSMutableArray *batch = [NSMutableArray array];
	NSEnumerator *en = [actions objectEnumerator];
	Action *action;
	while ((action = [en nextObject])) {
		if ([batch count] == 0) {
			[batch addObject:action];
			continue;
		}
		double maxBatchDelay = [[[batch objectAtIndex:0] valueForKey:@"delay"] doubleValue] + batchThreshold;
		if ([[action valueForKey:@"delay"] doubleValue] < maxBatchDelay) {
			[batch addObject:action];
			continue;
		}
		// Completed a batch
		[self increaseActionsInProgress];
		[NSThread detachNewThreadSelector:@selector(executeActionSetWithDelay:)
								 toTarget:self
							   withObject:batch];
		batch = [NSMutableArray arrayWithObject:action];
		continue;
	}

	// Final batch
	if ([batch count] > 0) {
		[self increaseActionsInProgress];
		[NSThread detachNewThreadSelector:@selector(executeActionSetWithDelay:)
								 toTarget:self
							   withObject:batch];
	}
}

- (void)triggerDepartureActions:(NSString *)fromUUID {
	NSArray *actions = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Actions"];
	NSMutableArray *actionsToRun = [NSMutableArray array];
	int max_delay = 0;

	// This is slightly trickier than triggerArrivalActions, since the "delay" value is
	// a reverse delay, rather than a forward delay. We scan through the actions, finding
	// all the ones that need to be run, calculating the maximum delay along the way.
	// We then go through those selected actions, and run a surrogate action for each with
	// a delay equal to (max_delay - original_delay).

	for (NSDictionary *action in actions) {
		NSString *when = [action objectForKey:@"when"];
		if (!([when isEqualToString:@"Departure"] || [when isEqualToString:@"Both"]))
			continue;
		if (![action[@"context"] isEqualToString:fromUUID])
			continue;
		if (![action[@"enabled"] boolValue])
			continue;

		NSNumber *aDelay = [action valueForKey:@"delay"];
		if (aDelay && ([aDelay doubleValue] > max_delay)) {
				max_delay = [aDelay doubleValue];
		}

        if ([[Action classForType:action[@"type"]] shouldWaitForScreenUnlock] && screenLocked) {
            [screenLockActionDepartureQueue addObject:[Action actionFromDictionary:action]];
        }
        else if ([[Action classForType:action[@"type"]] shouldWaitForScreensaverExit] && screenSaverRunning) {
            [screensaverActionDepartureQueue addObject:[Action actionFromDictionary:action]];
        }
        else {
            [actionsToRun addObject:action];
        }

	}

	NSMutableArray *set = [NSMutableArray arrayWithCapacity:[actionsToRun count]];
	for (NSDictionary *action in actionsToRun) {
		NSMutableDictionary *surrogateAction = [NSMutableDictionary dictionaryWithDictionary:action];
		double original_delay = [[action valueForKey:@"delay"] doubleValue];
		[surrogateAction setValue:[NSNumber numberWithDouble:(max_delay - original_delay)]
				   forKey:@"delay"];

        @try {
            [set addObject:[Action actionFromDictionary:surrogateAction]];
        }
        @catch (NSException *exception) {
            DSLog(@"ERROR: %@",NSLocalizedString(@"ControlPlane attempted to perform action it doesn't know about, you probably have a configured action that is no longer (or not yet) supported by ControlPlane", "ControlPlane was told to run an action that doesn't actually exist"));
        }
	}

	[self executeActionSet:set];

	// Finally, we have to sleep this thread, so we don't return until we're ready to change contexts.
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:max_delay]];
}

- (void)triggerArrivalActions:(NSString *)toUUID {
	NSArray *actions = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Actions"];

	NSMutableArray *set = [NSMutableArray array];
	for (NSDictionary *action in actions) {
		NSString *when = action[@"when"];
		if (!([when isEqualToString:@"Arrival"] || [when isEqualToString:@"Both"]))
			continue;
		if (![action[@"context"] isEqualToString:toUUID])
			continue;
		if (![action[@"enabled"] boolValue])
			continue;
        
        @try {
            if ([[Action classForType:action[@"type"]] shouldWaitForScreenUnlock] && screenLocked) {
                [screenLockActionArrivalQueue addObject:[Action actionFromDictionary:action]];
            }
            else if ([[Action classForType:action[@"type"]] shouldWaitForScreensaverExit] && screenSaverRunning) {
                [screensaverActionArrivalQueue addObject:[Action actionFromDictionary:action]];
            }
            else {
                [set addObject:[Action actionFromDictionary:action]];
            }
            
        }
        @catch (NSException *exception) {
            DSLog(@"ERROR: %@",NSLocalizedString(@"ControlPlane attempted to perform action it doesn't know about, you probably have a configured action that is no longer (or not yet) supported by ControlPlane", "ControlPlane was told to run an action that doesn't actually exist"));
        }
		
	}

	[self executeActionSet:set];
}

#pragma mark Context switching

- (void)performTransitionFrom:(NSString *)fromUUID to:(NSString *)toUUID withConfidenceMsg:(NSString *)confMsg {
	NSArray *walks = [contextsDataSource walkFrom:fromUUID to:toUUID];
	NSArray *leaving_walk = walks[0];
	NSArray *entering_walk = walks[1];

    NSDistributedNotificationCenter *dnc = [NSDistributedNotificationCenter defaultCenter];
    NSString *notificationObject = [[NSBundle mainBundle] bundleIdentifier];
    NSString *notificationName   = [notificationObject stringByAppendingString:@".ContextChanged"];
    
	[updatingSwitchingLock lock];

	// Execute all the "Departure" actions
    for (Context *ctxt in leaving_walk) {
		DSLog(@"Depart from %@", [ctxt name]);
		[self triggerDepartureActions:[ctxt uuid]];
	}

	NSString *ctxt_path = [contextsDataSource pathFromRootTo:toUUID];
    
	// Update current context
	[self setValue:toUUID forKey:@"currentContextUUID"];
	[self setValue:ctxt_path forKey:@"currentContextName"];
    
    NSDictionary *userInfo = @{ @"context": ctxt_path };
    [dnc postNotificationName:notificationName object:notificationObject userInfo:userInfo deliverImmediately:YES];
    
#if DEBUG_MODE
    // Create context named 'Developer Crash' and CP will crash when moving to it if using a DEBUG build
    // Allows you to test QuincyKit
    if ([ctxt_path isEqualToString:@"Developer Crash"]) {
        kill( getpid(), SIGABRT );
    }
#endif

    // Update menu bar (always do that in the main thread)
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateMenuBarImage];
        if ([[NSUserDefaults standardUserDefaults] floatForKey:@"menuBarOption"] != CP_DISPLAY_ICON) {
            [self setStatusTitle:currentContextName];
        }
    });
    
	[self postUserNotification:[[[NSString stringWithFormat:NSLocalizedString(@"Changing Context", @"Growl message title")] copy] autorelease]
	  withMessage:[[[NSString stringWithFormat:NSLocalizedString(@"Changing to context '%@' %@.",
								   @"First parameter is the context name, second parameter is the confidence value, or 'as default context'"),	ctxt_path, confMsg] copy] autorelease]];
    
	// Update force context menu
	NSMenu *menu = [forceContextMenuItem submenu];
    for (NSMenuItem *item in [menu itemArray]) {
		NSString *rep = [item representedObject];
		if (rep && [contextsDataSource contextByUUID:rep]) {
            BOOL ticked = ([rep isEqualToString:toUUID]);
            [item setState:(ticked ? NSOnState : NSOffState)];
        }
	}

	// Execute all the "Arrival" actions
    for (Context *ctxt in entering_walk) {
		DSLog(@"Arrive at %@", [ctxt name]);
		[self triggerArrivalActions:[ctxt uuid]];
	}

	[updatingSwitchingLock unlock];

	return;
}

#pragma mark Force switching

- (void)forceSwitch:(id)sender
{
	Context *ctxt = nil;
	
	if ([sender isKindOfClass:[Context class]])
		ctxt = (Context *) sender;
	else
		ctxt = [contextsDataSource contextByUUID:[sender representedObject]];
	
	DSLog(@"going to %@", [ctxt name]);

	// Selecting any context in the force-context menu deselects the 'stick forced contexts' item,
	// so we force it to be correct here.
	int state = forcedContextIsSticky ? NSOnState : NSOffState;
	[stickForcedContextMenuItem setState:state];
	
	[self performTransitionFrom:currentContextUUID to:[ctxt uuid] withConfidenceMsg:NSLocalizedString(@"(forced)", @"Used when force-switching to a context")];
}

- (void) setStickyBit:(NSNotification *) notification {
    if (![self stickyContext]) {
        [self toggleSticky:self];
    }
}

- (void) unsetStickyBit:(NSNotification *) notification {
    if ([self stickyContext]) {
        [self toggleSticky:self];
    }
}
- (void)toggleSticky:(id)sender
{
	BOOL oldValue = forcedContextIsSticky;
	forcedContextIsSticky = !oldValue;

	[stickForcedContextMenuItem setState:(forcedContextIsSticky ? NSOnState : NSOffState)];
}

- (void)forceSwitchAndToggleSticky:(id)sender
{
	[self toggleSticky:sender];
	[self forceSwitch:sender];
}

#pragma mark Thread stuff

// this method is the meat of ControlPlane, it is the engine that 
// determines if matching rules add up to the required confidence level
// and initiates a switch from one context to another

// TODO: allow multiple contexts to be active at once
- (void)doUpdateForReal {
    BOOL changed = NO;
    NSArray *matchingRules = [self getRulesThatMatchAndSetChangeFlag:&changed];
#ifdef DEBUG_MODE
    DSLog(@"rules that match: %@", matchingRules);
#endif

    if (!changed && !self.forceOneFullUpdate) {
#ifdef DEBUG_MODE
        DSLog(@"Same rule are matching as on previous check. No updates required.");
#endif
        return;
    }

    self.forceOneFullUpdate = NO;

    // Array of the UUIDs of all configured contexts, might look like this if UUIDs were simple text:
    // Top Level
    // Top Level 2
    //   Sub context of Top Level 2
    //     Sub context of sub context of Top Level 2
    NSArray *allConfiguredContexts = [contextsDataSource arrayOfUUIDs];
#ifdef DEBUG_MODE
    DSLog(@"context list %@", allConfiguredContexts);
#endif

    // of the configured contexts, which ones have rule hits?
    NSMutableDictionary *guesses = [self getGuessesForRules:matchingRules];
    DSLog(@"guesses %@", guesses);

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"AllowMultipleActiveContexts"]) {
        // use the newer style of context matching
        [guesses enumerateKeysAndObjectsUsingBlock:^(NSString *uuid, id aGuess, BOOL *stop) {
            NSArray *guess = [self getMostConfidentContext:@{ uuid: aGuess }];
            DSLog(@"currentGuess %@ should be %@", uuid, ([self guessMeetsConfidenceRequirement:guess]) ? @"enabled":@"disabled");
        }];
    } else {
        // Update what the user sees in preferences
        [self updateContextListView:allConfiguredContexts withGuesses:guesses];
        
        // use the older style of context matching
        // of the guesses, which one has the highest confidence rating?
        NSArray *mostConfidentGuess = [self getMostConfidentContext:guesses];

        if ([self guessMeetsConfidenceRequirement:mostConfidentGuess]) {
            NSString *confMsg = [self getGuessConfidenceStringFrom:mostConfidentGuess[1]];

            [self performTransitionFrom:currentContextUUID to:mostConfidentGuess[0] withConfidenceMsg:confMsg];
        }
    }
}

/**
 * Builds a list of guesses with their confidence values for the given (matching) rules
 * 
 * @param NSArray list of rules
 * @return NSMutableDictionary list of contexts with matching rules and their confidence values
 */
- (NSMutableDictionary *)getGuessesForRules:(NSArray *)rules {
	NSMutableDictionary *guesses = [NSMutableDictionary dictionary];

	// Maps a guessed context to an "unconfidence" value, which is
	// equal to (1 - confidence). We step through all the rules that are "hits",
	// and multiply this running unconfidence value by (1 - rule.confidence).
    for (NSDictionary *currentRule in rules) {
		// Rules apply to the stated context, as well as any subcontexts. We very slightly decay the amount
		// credited (proportional to the depth below the stated context), so that we don't guess a more
		// detailed context than is warranted.
        
        // get currentContextTree based on the current rule
        // Might look like
        // Sub context of Top Level 2
        //   Sub context of sub context of Top Level 2
		NSArray *currentContextTree = [contextsDataSource orderedTraversalRootedAt:currentRule[@"context"]];
        
		if ([currentContextTree count] == 0)
			continue;	// Oops, something got busted along the way
        
		const int base_depth = [[[currentContextTree objectAtIndex:0] valueForKey:@"depth"] intValue];
        const double currentRuleConfidence = [currentRule[@"confidence"] doubleValue];

		for (Context *currentContext in currentContextTree) {
			NSString *uuidOfCurrentContext = [currentContext uuid];
			const int depth = [[currentContext valueForKey:@"depth"] intValue];
			const double decay = 1.0 - (0.03 * (depth - base_depth));
            
            // seed unconfidenceValue with what we've calcuated so far
			NSNumber *unconfidenceValue = guesses[uuidOfCurrentContext];
			
            // if the unconfidenceValue isn't set initilialize it to a sane default
            if (!unconfidenceValue)
				unconfidenceValue = @(1.0);
            
            // account for the amount of confidence this matching rule affects the guess
			const double mult = currentRuleConfidence * decay;
			unconfidenceValue = @([unconfidenceValue doubleValue] * (1.0 - mult));
#ifdef DEBUG_MODE
			DSLog(@"crediting '%@' (d=%d|%d) with %.5f\t-> %@", [currentContext name], depth, base_depth, mult, unconfidenceValue);
#endif

			guesses[uuidOfCurrentContext] = unconfidenceValue;
		}
	}
    
    // convert unconfidence values to confidence values
    NSDictionary *guessesForConversion = [guesses copy];
    [guessesForConversion enumerateKeysAndObjectsUsingBlock:^(NSString *uuid, NSNumber *conf, BOOL *stop) {
        guesses[uuid] = @(1.0 - [conf doubleValue]);
    }];
    [guessesForConversion release];

    return guesses;
}


/**
 * Finds the most confidence guess
 * 
 * @param NSDictionary list of guesses
 * @return NSDictionary the most confident guess
 */
- (NSArray *) getMostConfidentContext:(NSDictionary *) guesses {
	__block NSString *guess = nil;
	__block double guessConf = -1.0; // guaranteed to be less than any actual confidence value

    // If configured to use a default context, add it here
    // and set the confidence value to exactly the minimum required
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    if ([standardUserDefaults boolForKey:@"UseDefaultContext"]) {
        guess = [standardUserDefaults stringForKey:@"DefaultContext"];
        guessConf = (double) [standardUserDefaults floatForKey:@"MinimumConfidenceRequired"];
    }

    // Finds the context with the highest confidence rating but not necessarily
    // one that satisfies the minimum confidence
    [guesses enumerateKeysAndObjectsUsingBlock:^(NSString *uuid, NSNumber *conf, BOOL *stop) {
	 	const double confindence = [conf doubleValue];
		if (confindence > guessConf) {
			guessConf = confindence;
            *stop = (confindence >= 1.0);
			guess = uuid;
		}
    }];

    if (guess) {
        return @[ guess, @(guessConf) ];
    }

    return @[];
}

- (void)updateContextListView:(NSArray *) allConfiguredContexts withGuesses:(NSDictionary *) guesses {
    // Update the values seen in the GUI.  This shows that there are rules that match
    // the context and what the "confidence" is for each
    for (NSString *uuid in allConfiguredContexts) {
		NSNumber *conf = guesses[uuid];
		NSString *newConfString = (conf) ? ([numberFormatter stringFromNumber:conf]) : (@"");

		Context *ctxt = [contextsDataSource contextByUUID:uuid];
		[ctxt setValue:newConfString forKey:@"confidence"];
	}

	// XXX: hackish -- but will be enough until 3.0
    // don't force data update if we're editing a context name
	NSOutlineView *olv = [contextsDataSource valueForKey:@"outlineView"];
	if (![olv currentEditor])
        [contextsDataSource triggerOutlineViewReloadData:nil];
}

- (NSString *)getGuessConfidenceStringFrom:(NSNumber *)confidence {
	return [NSString stringWithFormat:NSLocalizedString(@"with confidence %@", @"Appended to a context-change notification"), [numberFormatter stringFromNumber:confidence]];
}

/**
 * Decides if a given guess can become active
 */
- (BOOL)guessMeetsConfidenceRequirement:(NSArray *)guessArray {
    // if the guess dictionary is empty bail early
    if ([guessArray count] < 2) {
        return false;
    }

    NSString *guessUUID = guessArray[0];
    NSNumber *guessConf = guessArray[1];
    NSString *guessName = [[contextsDataSource contextByUUID:guessUUID] name];

    DSLog(@"checking %@ (%@) with confidence %@", guessName, guessUUID, guessConf);

    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];

    // this decides if the guess is confident enough
	if ([guessConf doubleValue] < [standardUserDefaults floatForKey:@"MinimumConfidenceRequired"]) {
#ifdef DEBUG_MODE
		NSString *guessConfidenceString = [self getGuessConfidenceStringFrom:guessConf];
        DSLog(@"Guess of '%@' isn't confident enough: only %@.", guessName, guessConfidenceString);
#endif
        return false;
	}

	if ([guessUUID isEqualToString:currentContextUUID]) {
#ifdef DEBUG_MODE
		NSString *guessConfidenceString = [self getGuessConfidenceStringFrom:guessConf];
		DSLog(@"Guessed '%@' (%@); already there.", guessName, guessConfidenceString);
#endif
		return false;
	}
    
    // the smoothing feature is designed to prevent ControlPlane from flapping between contexts
	if ([standardUserDefaults boolForKey:@"EnableSwitchSmoothing"]) {
		if (smoothCounter == 0) {
			smoothCounter = [standardUserDefaults integerForKey:@"SmoothSwitchCount"];	// Make this customisable?
		} else if (--smoothCounter == 0) {
#ifdef DEBUG_MODE
            DSLog(@"Switch smoothing kicking in... (%@ != %@)", currentContextName, guessName);
#endif
            return false;
        }
	}

    return true;
}

- (void)updateThread:(id)arg
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
	while (!timeToDie) {
		[updatingLock lockWhenCondition:1];
        
#ifdef DEBUG_MODE
        DSLog(@"**** DOING UPDATE LOOP ****");
#endif
		if (!forcedContextIsSticky && [[NSUserDefaults standardUserDefaults] boolForKey:@"Enabled"]) {
			[self doUpdateForReal];

			// Flush auto-release pool
			[pool release];
			pool = [[NSAutoreleasePool alloc] init];
		}

		[updatingLock unlockWithCondition:0];
	}

	[pool release];
}



- (void)goingToSleep:(id)arg
{
    // clear the queued actions on sleep
    // in case the machine woke up but the screen saver
    // was never exited or the screen was never unlocked
    // but then the machine went back to sleep
    
    // this might cause an issue with anyone who does an 
    // immediate action (not delayed at all) at sleep
    [self setGoingToSleep:YES];
    [screensaverActionArrivalQueue removeAllObjects];
    [screensaverActionDepartureQueue removeAllObjects];
    [screenLockActionDepartureQueue removeAllObjects];
    [screenLockActionArrivalQueue removeAllObjects];
	DSLog(@"Stopping update thread for sleep.");
	[updatingTimer setFireDate:[NSDate distantFuture]];
}

- (void)wakeFromSleep:(id)arg
{
    [self setGoingToSleep:NO];
	DSLog(@"Starting update thread after sleep.");
	[updatingTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
}

#pragma mark -
#pragma mark Screen Saver Monitoring
- (void) setScreenSaverActive:(NSNotification *) notification {
    [self setScreenSaverRunning:YES];
    DSLog(@"Screen saver is running");
}
- (void) setScreenSaverInActive:(NSNotification *) notification {
    [self setScreenSaverRunning:NO];
    [self executeActionSet:screensaverActionDepartureQueue];
    [self executeActionSet:screensaverActionArrivalQueue];
    [screensaverActionArrivalQueue removeAllObjects];
    [screensaverActionDepartureQueue removeAllObjects];
    DSLog(@"Screen saver is not running");
}

#pragma mark -
#pragma mark Screen Lock Monitoring

- (void) setScreenLockActive:(NSNotification *) notification {
    [self setScreenLocked:YES];
    DSLog(@"screen lock becoming active");
    
}

- (void) setScreenLockInActive:(NSNotification *) notification {
    [self setScreenLocked:NO];
    [self executeActionSet:screenLockActionDepartureQueue];
    [self executeActionSet:screenLockActionArrivalQueue];
    [screenLockActionDepartureQueue removeAllObjects];
    [screenLockActionArrivalQueue removeAllObjects];
    DSLog(@"screen lock becoming inactive");
}

//////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark -
#pragma mark NSApplication delegates

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
    [self showInStatusBar:self];
    [self startOrStopHidingFromStatusBar];
	return YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"EnablePersistentContext"]) {
		[[NSUserDefaults standardUserDefaults] setValue:currentContextUUID forKey:@"PersistentContext"];
	}
}

- (void) showMainApplicationWindow {
	[prefsWindow makeFirstResponder: nil];
}

#pragma mark NSUserDefaults notifications

- (void)userDefaultsChanged:(NSNotification *)notification {
    [self startOrStopHidingFromStatusBar];
    [self updateMenuBarImage];
    
    if ([[NSUserDefaults standardUserDefaults] floatForKey:@"menuBarOption"] == CP_DISPLAY_ICON) {
        [self setStatusTitle:nil];
    } else {
        [self setStatusTitle:currentContextName];
    }

#ifndef DEBUG_MODE
    // Force write of preferences
    [[NSUserDefaults standardUserDefaults] synchronize];
#endif

    // Check that the running evidence sources match the defaults
    if (!goingToSleep) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [evidenceSources startOrStopAll];
        });
    }
}

#pragma mark -
#pragma mark Evidence source change handling
- (void) evidenceSourceDataDidChange:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        // this will cause the updateThread to do it's work
#ifdef DEBUG_MODE
        DSLog(@"**** DOING UPDATE LOOP BECAUSE EVIDENCE SOURCE DATA CHANGED ****");
#endif
        [self doUpdate];
    });
}

@end
