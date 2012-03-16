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
#import <libkern/OSAtomic.h>

@interface CPController (Private) 

- (void)setStatusTitle:(NSString *)title;
- (void)showInStatusBar:(id)sender;
- (void)hideFromStatusBar:(NSTimer *)theTimer;
- (void)doHideFromStatusBar:(BOOL)forced;

- (void)doGrowl:(NSString *)title withMessage:(NSString *)message;
- (void)contextsChanged:(NSNotification *)notification;

- (void)doUpdate:(NSTimer *)theTimer;

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

@end

#pragma mark -

@implementation CPController

#define STATUS_BAR_LINGER	10	// seconds before disappearing from menu bar
#define CP_DISPLAY_ICON 0
#define CP_DISPLAY_CONTEXT 1
#define CP_DISPLAY_BOTH 2

@synthesize screenSaverRunning;
@synthesize screenLockStatus;

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
	[img setSize:NSMakeSize(18, 18)];

	return img;
}

- (id)init
{
	if (!(self = [super init]))
		return nil;

	sbImageActive = [self prepareImageForMenubar:@"cp-icon-active"];
	sbImageInactive = [self prepareImageForMenubar:@"cp-icon-inactive"];
	sbItem = nil;
	sbHideTimer = nil;
	updatingTimer = nil;

	updatingSwitchingLock = [[NSLock alloc] init];
    menuBarLocker = [[NSLock alloc] init];
	updatingLock = [[NSConditionLock alloc] initWithCondition:0];
	timeToDie = FALSE;
	smoothCounter = 0;

	// Set placeholder values
	[self setValue:@"" forKey:@"currentContextUUID"];
	[self setValue:@"?" forKey:@"currentContextName"];
	[self setValue:@"?" forKey:@"guessConfidence"];

	forcedContextIsSticky = NO;
	
	return self;
}

- (void)dealloc
{
	[updatingSwitchingLock release];
	[updatingLock release];

	[super dealloc];
}

- (NSString *) currentContextName {
	return currentContextName;
}

- (ContextsDataSource *) contextsDataSource {
	return contextsDataSource;
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
		NSLocalizedString(@"We strongly recommended that you review your preferences.", @"")];

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
	// Init Growl
	[GrowlApplicationBridge setGrowlDelegate: self];
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

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Debug OpenPrefsAtStartup"]) {
		[NSApp activateIgnoringOtherApps:YES];
		[prefsWindow makeKeyAndOrderFront:self];
	}

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(contextsChanged:)
												 name:@"ContextsChangedNotification"
											   object:contextsDataSource];
	[self contextsChanged:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(userDefaultsChanged:)
												 name:NSUserDefaultsDidChangeNotification
											   object:nil];

	// Get notified when we go to sleep, and wake from sleep
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
														   selector:@selector(goingToSleep:)
															   name:@"NSWorkspaceWillSleepNotification"
															 object:nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
														   selector:@selector(wakeFromSleep:)
															   name:@"NSWorkspaceDidWakeNotification"
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
    
    // set default screen saver and screen lock status
    [self setScreenLockStatus:NO];
    [self setScreenSaverRunning:NO];
    
	// Set up status bar.
	[self showInStatusBar:self];

	// Persistent contexts
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"EnablePersistentContext"]) {
		NSString *uuid = [[NSUserDefaults standardUserDefaults] stringForKey:@"PersistentContext"];
		Context *ctxt = [contextsDataSource contextByUUID:uuid];
		if (ctxt) {
			[self setValue:uuid forKey:@"currentContextUUID"];
			NSString *ctxt_path = [contextsDataSource pathFromRootTo:uuid];
			[self setValue:ctxt_path forKey:@"currentContextName"];
			if ([[NSUserDefaults standardUserDefaults] floatForKey:@"menuBarOption"] != CP_DISPLAY_ICON)
				[self setStatusTitle:ctxt_path];

			// Update force context menu
			NSMenu *menu = [forceContextMenuItem submenu];
			NSEnumerator *en = [[menu itemArray] objectEnumerator];
			NSMenuItem *item;
			while ((item = [en nextObject])) {
				NSString *rep = [item representedObject];
				if (!rep || ![contextsDataSource contextByUUID:rep])
					continue;
				BOOL ticked = ([rep isEqualToString:uuid]);
				[item setState:(ticked ? NSOnState : NSOffState)];
			}
		}
	}
	
	// update thread
	[NSThread detachNewThreadSelector:@selector(updateThread:)
							 toTarget:self
						   withObject:nil];
	
	// sleep thread
	[NSThread detachNewThreadSelector:@selector(monitorSleepThread:)
							 toTarget:self
						   withObject:nil];

	// Start up evidence sources that should be started
	[evidenceSources startOrStopAll];

	// Schedule a one-off timer (in 2s) to get initial data.
	// Future recurring timers will be set automatically from there.
	updatingTimer = [[NSTimer scheduledTimerWithTimeInterval: (NSTimeInterval)2
													  target: self
													selector: @selector(doUpdate:)
													userInfo: nil
													 repeats: NO] retain];
	
	[NSApp unhide];
}



#pragma mark Menu Bar Wrangling


- (void)setStatusTitle:(NSString *)title
{
    [menuBarLocker lock];

	if (!sbItem) {
        [menuBarLocker unlock];
		return;
    }
	if (!title) {
		[sbItem setTitle:nil];
        [menuBarLocker unlock];
		return;
	}

	// Smaller font
	NSFont *font = [NSFont menuBarFontOfSize:10.0];
	NSDictionary *attrs = [NSDictionary dictionaryWithObject:font
							  forKey:NSFontAttributeName];
	NSAttributedString *as = [[NSAttributedString alloc] initWithString:title attributes:attrs];
	[sbItem setAttributedTitle:[as autorelease]];

    [menuBarLocker unlock];
}

- (void)setMenuBarImage:(NSImage *)imageName {

    [menuBarLocker lock];
    // if the menu bar item has been hidden sbItem will have been released
    // and we should not attempt to update the image
    if (!sbItem) {

        [menuBarLocker unlock];
        return;
    }

    
    @try {
        [sbItem setImage:imageName];
    }
    @catch (NSException *exception) {
        DSLog(@"failed to set the menubar icon to %@ with error %@.  Please alert ControlPlane Developers!", [imageName name], [exception reason]);
        [self setStatusTitle:@"Failed to set icon"];
    }

    [menuBarLocker unlock];
}

- (void)showInStatusBar:(id)sender
{

    [menuBarLocker lock];
	if (sbItem) {
		// Already there? Rebuild it anyway.
       	sbHideTimer = [sbHideTimer checkAndInvalidate];
        [self doHideFromStatusBar:YES];
	}

	sbItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
	[sbItem retain];
	[sbItem setHighlightMode:YES];

    [menuBarLocker unlock];

    // only show the icon if preferences say we should
    if ([[NSUserDefaults standardUserDefaults] floatForKey:@"menuBarOption"] != CP_DISPLAY_CONTEXT) {
        [self setMenuBarImage:(guessIsConfident ? sbImageActive : sbImageInactive)];
    }
    else {
        [self setMenuBarImage:NULL];
    }
    
    if ([[NSUserDefaults standardUserDefaults] floatForKey:@"menuBarOption"] != CP_DISPLAY_ICON) {
        [self setStatusTitle:currentContextName];
    }
	
	[sbItem setMenu:sbMenu];

}

- (void)hideFromStatusBar:(NSTimer *)theTimer {

    [menuBarLocker lock];
    
	sbHideTimer = [sbHideTimer checkAndInvalidate];
	
    [self doHideFromStatusBar:NO];
    

    [menuBarLocker unlock];
}


- (void)doHideFromStatusBar:(BOOL)forced {
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"HideStatusBarIcon"] && !forced)
		return;
    
    if (sbItem) {
        [[NSStatusBar systemStatusBar] removeStatusItem:sbItem];
        [sbItem release];
        sbItem = nil;
    }
}

- (void)doGrowl:(NSString *)title withMessage:(NSString *)message
{
    /*
    // because actions are performed on their own thread, it's possible
    // for doGrowl to be called by each simultaneously especially in the 
    // case that an action fails, need to provide some order here to prevent 
    // the title/message from being clobbered
    
    static int32_t alreadyHere = 0;
    */
    BOOL useGrowl = [[NSUserDefaults standardUserDefaults] boolForKey:@"EnableGrowl"];
    if (!useGrowl)
        return;
    
    /*
    while (alreadyHere) {
        [NSThread sleepForTimeInterval:0.5];
    }
    OSAtomicIncrement32(&alreadyHere);
    */

	
	signed int pri = 0;

	if ([title isEqualToString:@"Failure"])
		pri = 1;

	[GrowlApplicationBridge notifyWithTitle:title
								description:message
						   notificationName:title
								   iconData:nil
								   priority:pri
								   isSticky:NO
							   clickContext:nil];
    //OSAtomicDecrement32(&alreadyHere);

}

- (void)contextsChanged:(NSNotification *)notification
{
#ifdef DEBUG_MODE
    DSLog(@"in contextChanged");
#endif
	// Fill in 'Force context' submenu
	NSMenu *submenu = [[[NSMenu alloc] init] autorelease];
	NSEnumerator *en = [[contextsDataSource orderedTraversal] objectEnumerator];
	Context *ctxt;
	while ((ctxt = [en nextObject])) {
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
	ctxt = [contextsDataSource contextByUUID:currentContextUUID];
	if (ctxt) {
		[self setValue:[ctxt name] forKey:@"currentContextName"];
	} else {
		// Our current context was removed
		[self setValue:@""  forKey:@"currentContextUUID"];
		[self setValue:@"?" forKey:@"currentContextName"];
		[self setValue:@"?" forKey:@"guessConfidence"];
	}


    if ([[NSUserDefaults standardUserDefaults] floatForKey:@"menuBarOption"] != CP_DISPLAY_ICON) {
		[self setStatusTitle:[contextsDataSource pathFromRootTo:currentContextUUID]];
        [self showInStatusBar:self];
    }

	// update other stuff?
}

#pragma mark Rule matching and Action triggering

- (void)doUpdate:(NSTimer *)theTimer
{
	// Check timer interval
	NSTimeInterval intv = [[NSUserDefaults standardUserDefaults] floatForKey:@"UpdateInterval"];
	if (fabs(intv - [updatingTimer timeInterval]) > 0.1) {
		updatingTimer = [updatingTimer checkAndInvalidate];
		updatingTimer = [[NSTimer scheduledTimerWithTimeInterval: intv
														  target: self
														selector: @selector(doUpdate:)
														userInfo: nil
														 repeats: YES] retain];
	}

	// Check status bar visibility
	BOOL hide = [[NSUserDefaults standardUserDefaults] boolForKey:@"HideStatusBarIcon"];
	if (sbItem && hide && !sbHideTimer)
		sbHideTimer = [[NSTimer scheduledTimerWithTimeInterval: (NSTimeInterval)STATUS_BAR_LINGER
														target: self
													  selector: @selector(hideFromStatusBar:)
													  userInfo: nil
													   repeats: NO] retain];
	else if (!hide)
		sbHideTimer = [sbHideTimer checkAndInvalidate];
	
	if (!hide && !sbItem) {
		[self showInStatusBar:self];
    }
    if ([[NSUserDefaults standardUserDefaults] floatForKey:@"menuBarOption"] != CP_DISPLAY_ICON) {
        [self setStatusTitle:[contextsDataSource pathFromRootTo:currentContextUUID]];
    }

	[updatingLock lock];
    if ([[NSUserDefaults standardUserDefaults] floatForKey:@"menuBarOption"] == CP_DISPLAY_CONTEXT)
        [self setMenuBarImage:NULL];

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

// (Private) in a new thread, execute Action immediately, growling upon failure
- (void)executeAction:(id)arg
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	Action *action = (Action *) arg;

	NSString *errorString;
	if (![action execute:&errorString])
		[self doGrowl:[[[NSString stringWithFormat:NSLocalizedString(@"Failure", @"Growl message title")] copy] autorelease] withMessage:[[errorString copy] autorelease]];
	
	[self decreaseActionsInProgress];
	[pool release];
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
	[self doGrowl:[[growlTitle copy] autorelease] withMessage:[[growlMessage copy] autorelease]];

	NSEnumerator *en = [actions objectEnumerator];
	Action *action;
	while ((action = [en nextObject])) {
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
		NSString *when = [action objectForKey:@"when"];
		if (!([when isEqualToString:@"Departure"] || [when isEqualToString:@"Both"]))
			continue;
		if (![[action objectForKey:@"context"] isEqualToString:fromUUID])
			continue;
		if (![[action objectForKey:@"enabled"] boolValue])
			continue;

		NSNumber *aDelay;
		if ((aDelay = [action valueForKey:@"delay"])) {
			if ([aDelay doubleValue] > max_delay)
				max_delay = [aDelay doubleValue];
		}

		[actionsToRun addObject:action];

	}

	action_enum = [actionsToRun objectEnumerator];
	NSMutableArray *set = [NSMutableArray array];
	while ((action = [action_enum nextObject])) {
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

- (void)triggerArrivalActions:(NSString *)toUUID
{
	NSArray *actions = [actionsController arrangedObjects];

	NSEnumerator *action_enum = [actions objectEnumerator];
	NSDictionary *action;
	NSMutableArray *set = [NSMutableArray array];
	while (action = [action_enum nextObject]) {
		NSString *when = [action objectForKey:@"when"];
		if (!([when isEqualToString:@"Arrival"] || [when isEqualToString:@"Both"]))
			continue;
		if (![[action objectForKey:@"context"] isEqualToString:toUUID])
			continue;
		if (![[action objectForKey:@"enabled"] boolValue])
			continue;
        
        @try {
            [set addObject:[Action actionFromDictionary:action]];
        }
        @catch (NSException *exception) {
            DSLog(@"ERROR: %@",NSLocalizedString(@"ControlPlane attempted to perform action it doesn't know about, you probably have a configured action that is no longer (or not yet) supported by ControlPlane", "ControlPlane was told to run an action that doesn't actually exist"));
        }
		
	}

	[self executeActionSet:set];
}

#pragma mark Context switching

- (void)performTransitionFrom:(NSString *)fromUUID to:(NSString *)toUUID
{
#ifdef DEBUG_MODE
    DSLog(@"in performTranisitionFrom");
#endif
	NSArray *walks = [contextsDataSource walkFrom:fromUUID to:toUUID];
	NSArray *leaving_walk = [walks objectAtIndex:0];
	NSArray *entering_walk = [walks objectAtIndex:1];
	NSEnumerator *en;
	Context *ctxt;

	[updatingSwitchingLock lock];

	// Execute all the "Departure" actions
	en = [leaving_walk objectEnumerator];
	while ((ctxt = [en nextObject])) {
		DSLog(@"Depart from %@", [ctxt name]);
		[self triggerDepartureActions:[ctxt uuid]];
	}

	// Update current context
	[self setValue:toUUID forKey:@"currentContextUUID"];
	NSString *ctxt_path = [contextsDataSource pathFromRootTo:toUUID];
    
    NSString *notificationObject = [[NSBundle mainBundle] bundleIdentifier];
    NSString *notificationName = [NSString stringWithFormat:@"%@.ContextChanged",notificationObject];
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:ctxt_path, @"context", nil];
                              
    NSDistributedNotificationCenter *dnc = [NSDistributedNotificationCenter defaultCenter];
                              [dnc postNotificationName:notificationName object:notificationObject userInfo:userInfo deliverImmediately:YES];
    
    // Create context named 'Developer Crash' and CP will crash when moving to it if using a DEBUG build
    // Allows you to test QuinyKit
    if ([ctxt_path isEqualToString:@"Developer Crash"]) {
#if DEBUG_MODE
        kill( getpid(), SIGABRT );
#endif
    }
    
	[self doGrowl:[[[NSString stringWithFormat:NSLocalizedString(@"Changing Context", @"Growl message title")] copy] autorelease]
	  withMessage:[[[NSString stringWithFormat:NSLocalizedString(@"Changing to context '%@' %@.",
								   @"First parameter is the context name, second parameter is the confidence value, or 'as default context'"),	ctxt_path, guessConfidence] copy] autorelease]];
    
	[self setValue:ctxt_path forKey:@"currentContextName"];
    if ([[NSUserDefaults standardUserDefaults] floatForKey:@"menuBarOption"] != CP_DISPLAY_ICON) {
        [self setStatusTitle:ctxt_path];
     
    }
	/*if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowGuess"])
		[self setStatusTitle:ctxt_path];*/

	// Update force context menu
	NSMenu *menu = [forceContextMenuItem submenu];
	en = [[menu itemArray] objectEnumerator];
	NSMenuItem *item;
	while ((item = [en nextObject])) {
		NSString *rep = [item representedObject];
		if (!rep || ![contextsDataSource contextByUUID:rep])
			continue;
		BOOL ticked = ([rep isEqualToString:toUUID]);
		[item setState:(ticked ? NSOnState : NSOffState)];
	}

	// Execute all the "Arrival" actions
	en = [entering_walk objectEnumerator];
	while ((ctxt = [en nextObject])) {
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
	[self setValue:NSLocalizedString(@"(forced)", @"Used when force-switching to a context")
		forKey:@"guessConfidence"];

	// Selecting any context in the force-context menu deselects the 'stick forced contexts' item,
	// so we force it to be correct here.
	int state = forcedContextIsSticky ? NSOnState : NSOffState;
	[stickForcedContextMenuItem setState:state];
	
	[self performTransitionFrom:currentContextUUID to:[ctxt uuid]];
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
- (void)doUpdateForReal
{
    // Array of the UUIDs of all configured contexts, might look like this if UUIDs were simple text:
    // Top Level
    // Top Level 2
    //   Sub context of Top Level 2
    //     Sub context of sub context of Top Level 2
	NSArray *allConfiguredContexts = [contextsDataSource arrayOfUUIDs];
	
	// Maps a guessed context to an "unconfidence" value, which is
	// equal to (1 - confidence). We step through all the rules that are "hits",
	// and multiply this running unconfidence value by (1 - rule.confidence).
	NSMutableDictionary *guesses = [NSMutableDictionary dictionaryWithCapacity:[allConfiguredContexts count]];
	NSArray *rule_hits = [self getRulesThatMatch];
	NSEnumerator *ruleHitsEnumerator = [rule_hits objectEnumerator];
	NSDictionary *currentRule;
    

	while (currentRule = [ruleHitsEnumerator nextObject]) {
		// Rules apply to the stated context, as well as any subcontexts. We very slightly decay the amount
		// credited (proportional to the depth below the stated context), so that we don't guess a more
		// detailed context than is warranted.
        
        // get currentContextTree based on the current rule
        // Might look like
        // Sub context of Top Level 2
        //   Sub context of sub context of Top Level 2
		NSArray *currentContextTree = [contextsDataSource orderedTraversalRootedAt:[currentRule valueForKey:@"context"]];
        
#ifdef DEBUG_MODE
        DSLog(@"currentContextTree looks like %@", currentContextTree);
#endif
        
        
		if ([currentContextTree count] == 0)
			continue;	// Oops, something got busted along the way
        
        
		NSEnumerator *currentContextTreeEnumerator = [currentContextTree objectEnumerator];
		Context *currentContext;
		int base_depth = [[[currentContextTree objectAtIndex:0] valueForKey:@"depth"] intValue];
        
        
		while ((currentContext = [currentContextTreeEnumerator nextObject])) {
			NSString *uuidOfCurrentContext = [currentContext uuid];
			int depth = [[currentContext valueForKey:@"depth"] intValue];
			double decay = 1.0 - (0.03 * (depth - base_depth));

            // seed unconfidenceValue with what we've calcuated so far
            // this effectively
			NSNumber *unconfidenceValue = [guesses objectForKey:uuidOfCurrentContext];
            
			
            // if the unconfidenceValue isn't set initilialize it to a sane default
            if (!unconfidenceValue)
				unconfidenceValue = [NSNumber numberWithDouble:1.0];
            
            
            // account for the amount of confidence this matching rule affects the guess
			double mult = [[currentRule valueForKey:@"confidence"] doubleValue] * decay;
			unconfidenceValue = [NSNumber numberWithDouble:[unconfidenceValue doubleValue] * (1.0 - mult)];
#ifdef DEBUG_MODE
			DSLog(@"crediting '%@' (d=%d|%d) with %.5f\t-> %@", [currentContext name], depth, base_depth, mult, unconfidenceValue);
#endif
			[guesses setObject:unconfidenceValue forKey:uuidOfCurrentContext];
		}
	}
    
#ifdef DEBUG_MODE
    DSLog(@"guesses looks like %@", guesses);
#endif

    
	// Finds the context with the highest confidence rating
	ruleHitsEnumerator = [guesses keyEnumerator];
	NSString *uuid, *guess = nil;
	double guessConf = 0.0;
	while ((uuid = [ruleHitsEnumerator nextObject])) {
		double uncon = [[guesses objectForKey:uuid] doubleValue];
		double con = 1.0 - uncon;
		if ((con > guessConf) || !guess) {
			guess = uuid;
			guessConf = con;
		}
	}

    
    // Update the values seen in the GUI

	NSNumberFormatter *numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
	[numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
	[numberFormatter setNumberStyle:NSNumberFormatterPercentStyle];

    
    

	ruleHitsEnumerator = [allConfiguredContexts objectEnumerator];
	while ((uuid = [ruleHitsEnumerator nextObject])) {
		Context *ctxt = [contextsDataSource contextByUUID:uuid];
		NSString *newConfString = @"";
		NSNumber *unconf = [guesses objectForKey:uuid];
		if (unconf) {
			double con = 1.0 - [unconf doubleValue];
			newConfString = [numberFormatter stringFromNumber:[NSNumber numberWithDouble:con]];
		}
		[ctxt setValue:newConfString forKey:@"confidence"];
	}
#if 1
	// XXX: hackish -- but will be enough until 3.0
    // don't force data update if we're editing a context name
	NSOutlineView *olv = [contextsDataSource valueForKey:@"outlineView"];
	if (![olv currentEditor])	
#endif
		[contextsDataSource triggerOutlineViewReloadData:nil];

	
    


	NSString *perc = [numberFormatter stringFromNumber:[NSNumber numberWithDouble:guessConf]];
	NSString *guessConfidenceString = [NSString stringWithFormat:
		NSLocalizedString(@"with confidence %@", @"Appended to a context-change notification"),
		perc];
    
    // This covers the case where the show context in menu bar option has been changed
	if ([[NSUserDefaults standardUserDefaults] floatForKey:@"menuBarOption"] == CP_DISPLAY_ICON)
		[self setStatusTitle:nil];
    
#ifdef DEBUG_MODE
	NSString *guessString = [[contextsDataSource contextByUUID:guess] name];
#endif

	BOOL no_guess = NO;
	if (!guess) {
#ifdef DEBUG_MODE
		DSLog(@"No guess made.");
#endif
		no_guess = YES;
	} else if (guessConf < [[NSUserDefaults standardUserDefaults] floatForKey:@"MinimumConfidenceRequired"]) {
#ifdef DEBUG_MODE
		DSLog(@"Guess of '%@' isn't confident enough: only %@.", guessString, guessConfidenceString);
#endif
		no_guess = YES;
	}

	if (no_guess) {
		guessIsConfident = NO;
        if ([[NSUserDefaults standardUserDefaults] floatForKey:@"menuBarOption"] != CP_DISPLAY_CONTEXT)
            [self setMenuBarImage:sbImageInactive];

		if (![[NSUserDefaults standardUserDefaults] boolForKey:@"UseDefaultContext"])
			return;
		guess = [[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultContext"];
		Context *ctxt;
		if (!(ctxt = [contextsDataSource contextByUUID:guess]))
			return;
		guessConfidenceString = NSLocalizedString(@"as default context",
							  @"Appended to a context-change notification");
#ifdef DEBUG_MODE
		guessString = [ctxt name];
#endif
	}

	guessIsConfident = YES;
    
    if ([[NSUserDefaults standardUserDefaults] floatForKey:@"menuBarOption"] != CP_DISPLAY_CONTEXT)
        [self setMenuBarImage:sbImageActive];

	BOOL do_switch = YES;

	BOOL smoothing = [[NSUserDefaults standardUserDefaults] boolForKey:@"EnableSwitchSmoothing"];
	if (smoothing && ![currentContextUUID isEqualToString:guess]) {
		if (smoothCounter == 0) {
			smoothCounter = [[NSUserDefaults standardUserDefaults] integerForKey:@"SmoothSwitchCount"];	// Make this customisable?
			do_switch = NO;
		} else if (--smoothCounter > 0)
			do_switch = NO;
#ifdef DEBUG_MODE
		if (!do_switch)
			DSLog(@"Switch smoothing kicking in... (%@ != %@)", currentContextName, guessString);
#endif
	}
    
    if ([self screenLockStatus] || [self screenSaverRunning]) {
        DSLog(@"not switching because the the screen saver is running or the screen is locked");
        do_switch = NO;
    }

	[self setValue:guessConfidenceString forKey:@"guessConfidence"];

	if (!do_switch)
		return;

	if ([guess isEqualToString:currentContextUUID]) {
#ifdef DEBUG_MODE
		DSLog(@"Guessed '%@' (%@); already there.", guessString, guessConfidenceString);
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

		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Enabled"] &&
		    !forcedContextIsSticky) {
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
	DSLog(@"Stopping update thread for sleep.");
	[updatingTimer setFireDate:[NSDate distantFuture]];
}

- (void)wakeFromSleep:(id)arg
{
	DSLog(@"Starting update thread after sleep.");
	[updatingTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
}

#pragma mark -
#pragma mark Screen Saver Monitoring
- (void) setScreenSaverActive {
    [self setScreenSaverRunning:YES];
    DSLog(@"Screen saver is running");
}
- (void) setScreenSaverInActive {
    [self setScreenSaverRunning:NO];
    DSLog(@"Screen saver is not running");
}

#pragma mark -
#pragma mark Screen Lock Monitoring

- (void) setScreenLockActive:(NSNotification *) notification {
    [self setScreenLockStatus:YES];
    DSLog(@"screen lock becoming active");
    
}

- (void) setScreenLockInActive:(NSNotification *) notification {
    [self setScreenLockStatus:NO];
    DSLog(@"screen lock becoming inactive");
}

//////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark -
#pragma mark NSApplication delegates

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
	// Set up status bar.
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"HideStatusBarIcon"]) {
		[self showInStatusBar:self];
		sbHideTimer = [[NSTimer scheduledTimerWithTimeInterval: (NSTimeInterval)STATUS_BAR_LINGER
														target: self
													  selector: @selector(hideFromStatusBar:)
													  userInfo: nil
													   repeats: NO] retain];
	}

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

- (void)userDefaultsChanged:(NSNotification *)notification
{
#ifndef DEBUG_MODE
	// Force write of preferences
	[[NSUserDefaults standardUserDefaults] synchronize];
#endif

	// Check that the running evidence sources match the defaults
	[evidenceSources startOrStopAll];
}

@end
