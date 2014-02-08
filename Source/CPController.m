//
//  CPController.m
//  ControlPlane
//
//  Created by David Symonds on 1/02/07.
//  Major rework by Vladimir Beloborodov (VladimirTechMan) in Q2-Q3 2013.
//

#import "Action.h"
#import "DSLogger.h"
#import "CPController.h"
#import "CPController+SleepMonitor.h"
#import "NetworkLocationAction.h"
#import "NSTimer+Invalidation.h"
#import "CPNotifications.h"
#import "SharedNumberFormatter.h"
#import <libkern/OSAtomic.h>


#pragma mark -
#pragma mark NSArray Extensions

@implementation NSArray (ComponentsAtIndexesJoinedByString)

- (NSString *)componentsAtIndexes:(NSIndexSet *)indexes joinedByString:(NSString *)separator {
    NSMutableString *str = [NSMutableString string];
    [self enumerateObjectsAtIndexes:indexes options:0 usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([str length]) {
            [str appendString:separator];
        }
        [str appendString:[obj description]];
    }];
    return str;
}

- (NSMutableArray *)deepMutableCopy {
    NSMutableArray *arrayMutableCopy = [NSMutableArray arrayWithCapacity:[self count]];
    for (id obj in self) {
        id objMutableCopy = [obj mutableCopy];
        [arrayMutableCopy addObject:objMutableCopy];
        [objMutableCopy release];
    }
    return arrayMutableCopy;
}

@end

#pragma mark -
#pragma mark CPController

@interface CPController () {
@private
	IBOutlet NSMenu *sbMenu;
	NSStatusItem *sbItem;
	NSImage *sbImageActive, *sbImageInactive;
	NSTimer *sbHideTimer;
    
	IBOutlet NSMenuItem *forceContextMenuItem;
	BOOL forcedContextIsSticky;
	//NSMenuItem *stickForcedContextMenuItem;
    
	IBOutlet ContextsDataSource *contextsDataSource;
	IBOutlet EvidenceSourceSetController *evidenceSources;
	IBOutlet NSWindow *prefsWindow;
    
    BOOL screenSaverRunning;
    BOOL screenLocked;
    
    BOOL goingToSleep;

	NSInteger smoothCounter; // Switch smoothing state parameters
    
    // used to maintain a queue of actions that need
    // to be performed after the screen saver quits AND/OR
    // the screen is unlocked
    NSMutableArray *screenSaverActionQueue;
    NSMutableArray *screenLockActionQueue;
    
    dispatch_queue_t concurrentActionQueue;
    dispatch_queue_t updatingQueue;
    dispatch_source_t updatingTimer;
    int64_t updateInterval;
}

@property (retain,atomic,readwrite) Context *currentContext;
@property (retain,atomic,readwrite) NSString *currentContextPath;

@property (copy,nonatomic,readwrite) NSString *candidateContextUUID; // Switch smoothing state parameters

@property (strong,nonatomic,readwrite) NSMutableSet *candidateContextsToActivate;
@property (strong,nonatomic,readwrite) NSMutableSet *candidateContextsToDeactivate;

@property (retain,atomic,readwrite) NSArray *rules;
@property (assign,atomic,readwrite) BOOL forceOneFullUpdate;

- (void)setStatusTitle:(NSString *)title;
- (void)showInStatusBar:(id)sender;
- (void)hideFromStatusBar:(NSTimer *)theTimer;
- (void)doHideFromStatusBar:(BOOL)forced;
- (void)setMenuBarImage:(NSImage *)imageName;

- (void)contextsChanged:(NSNotification *)notification;

- (void)goingToSleep:(id)arg;
- (void)wakeFromSleep:(id)arg;

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag;
- (void)applicationWillTerminate:(NSNotification *)aNotification;

- (void)userDefaultsChanged:(NSNotification *)notification;

// Evidence source monitoring
- (void)evidenceSourceDataDidChange:(NSNotification *) notification;

- (void)forceSwitchAndToggleSticky:(id)sender;
- (void)setStickyBit:(NSNotification *) notification;
- (void)unsetStickyBit:(NSNotification *) notification;

- (void)registerForNotifications;

@end


#pragma mark -

@implementation CPController

#define STATUS_BAR_LINGER	10	// seconds before disappearing from menu bar
#define CP_DISPLAY_ICON     0u
#define CP_DISPLAY_CONTEXT  1u
#define CP_DISPLAY_BOTH     2u

@synthesize screenSaverRunning;
@synthesize screenLocked;
@synthesize goingToSleep;

+ (void)initialize {
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
	[appDefaults setValue:[NSNumber numberWithBool:NO]  forKey:@"EnableBluetoothEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:NO]  forKey:@"EnableDNSEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:NO]  forKey:@"EnableFireWireEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnableIPAddrEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:NO]  forKey:@"EnableLightEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnableMonitorEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnablePowerEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnableRunningApplicationEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnableTimeOfDayEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:YES] forKey:@"EnableUSBEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:NO]  forKey:@"EnableCoreWLANEvidenceSource"];
    [appDefaults setValue:[NSNumber numberWithBool:NO]  forKey:@"EnableSleep/WakeEvidenceSource"];
	[appDefaults setValue:[NSNumber numberWithBool:NO]  forKey:@"EnableCoreLocationSource"];

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
- (NSImage *)prepareImageForMenubar:(NSString *)name {
	NSImage *img = [NSImage imageNamed:name];
	[img setScalesWhenResized:YES];
    // TODO: provide images for retina displays
	[img setSize:NSMakeSize(18, 18)];

	return img;
}

- (void)changeActiveIconImageColorTo:(NSColor *)color {
    @try {
        [sbImageActive lockFocus];
        [color set];
        NSRectFillUsingOperation((NSRect) {NSZeroPoint, sbImageActive.size}, NSCompositeSourceIn);
        [sbImageActive unlockFocus];
        [sbImageActive recache];
    }
    @catch (NSException *e) {
        DSLog(@"Failed to change the color of status bar icon");
    }
}

- (id)init {
	if (!(self = [super init])) {
		return nil;
    }

	sbImageActive   = [[self prepareImageForMenubar:@"cp-icon-active"]   retain];
	sbImageInactive = [[self prepareImageForMenubar:@"cp-icon-inactive"] retain];

	sbItem = nil;
	sbHideTimer = nil;

	[self restartSwitchSmoothing];
    [self setGoingToSleep:NO];

	forcedContextIsSticky = NO;

    screenSaverActionQueue = [[NSMutableArray alloc] init];
    screenLockActionQueue = [[NSMutableArray alloc] init];

    if (![self doInitUpdatingQueue]) {
        [self release];
        return nil;
    }
    
    NSArray *rulesInUserDefaults = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Rules"];
    _rules = [[rulesInUserDefaults deepMutableCopy] retain];

    _forceOneFullUpdate = YES;
    
	return self;
}

- (void)dealloc {
    [self stopMonitoringSleepAndPowerNotifications];
    [self doReleaseUpdatingQueue];

    [_rules release];
    [_candidateContextUUID release];

    [screenLockActionQueue release];
    [screenSaverActionQueue release];

    [sbImageActive release];
    [sbImageInactive release];

    [_currentContextPath release];
    [_currentContext release];
    
	[super dealloc];
}

- (ContextsDataSource *)contextsDataSource {
	return contextsDataSource;
}


- (NSArray *)activeRules {
    return [self.rules deepMutableCopy];
}

- (void)setActiveRules:(NSArray *)newRules {
    NSMutableArray *rules = [[NSMutableArray alloc] initWithCapacity:[newRules count]];
    
    for (NSDictionary *ruleParams in newRules) {
        NSMutableDictionary *rule = [ruleParams mutableCopy];
        
        // remove all previously cached data
        for (NSString *key in [rule allKeys]) {
            if ([key hasPrefix:@"cached"]) {
                [rule removeObjectForKey:key];
            }
        }
        
        [rules addObject:rule];
        [rule release];
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:rules forKey:@"Rules"];
    
    self.rules = rules; // atomic
    self.forceOneFullUpdate = YES;
    
    [rules release];
    
    [self shiftRegularUpdatesToStartAt:dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC)];
}

- (BOOL)stickyContext {
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
- (BOOL)importMarcoPoloSettings {
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

    // set default screen saver and screen lock status
    [self setScreenLocked:NO];
    [self setScreenSaverRunning:NO];

    [self startMonitoringSleepAndPowerNotifications];
    [self registerForNotifications];
    self.activeContexts = [NSMutableSet setWithCapacity:0];
    self.stickyActiveContexts = [NSMutableSet setWithCapacity:0];
    
    self.candidateContextsToActivate   = [NSMutableSet set];
    self.candidateContextsToDeactivate = [NSMutableSet set];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Start up evidence sources that should be started
        [evidenceSources startEnabledEvidenceSources];
        [self resumeRegularUpdatesWithDelay:(2 * NSEC_PER_SEC)];
    });
    
    [self rebuildForceContextMenu];
    
	// Persistent contexts
	Context *startContext = nil;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"EnablePersistentContext"]) {
		NSString *uuid = [[NSUserDefaults standardUserDefaults] stringForKey:@"PersistentContext"];
        startContext = [contextsDataSource contextByUUID:uuid];
	}
    [self changeCurrentContextTo:startContext];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Set up status bar.
        [self showInStatusBar:self];
        [self startOrStopHidingFromStatusBar];

        [NSApp unhideWithoutActivation];

        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Debug OpenPrefsAtStartup"]) {
            [NSApp activateIgnoringOtherApps:YES];
            [prefsWindow makeKeyAndOrderFront:self];
        }
        [self updateActiveContextsMenuTitle];
        [self updateActiveContextsMenuList];
    });
    
    // hide the current context menu item for now
    [self.currentContextNameMenuItem setHidden:YES];
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:@"AllowMultipleActiveContexts" options:NSKeyValueObservingOptionNew context:nil];
}


#pragma mark Register for notifications

- (void)registerForNotifications {
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

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateMenuBarImageOnIconColorPreviewNotification:)
                                                 name:@"iconColorPreviewRequested"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateMenuBarImageOnIconColorPreviewNotification:)
                                                 name:@"iconColorPreviewFinished"
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

- (void)updateMenuBarImageOnIconColorPreviewNotification:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    if (userInfo) {
        NSColor *color = userInfo[@"color"];
        [self changeActiveIconImageColorTo:((color) ? (color) : ([NSColor blackColor]))];
        [self setMenuBarImage:sbImageActive];
    } else {
        [self updateMenuBarImage];
    }
}

- (void)updateMenuBarImage {
	if (!sbItem) {
		return;
    }

    NSImage *barImage = nil;
    if ([[NSUserDefaults standardUserDefaults] integerForKey:@"menuBarOption"] != CP_DISPLAY_CONTEXT) {
        Context *currentContext = self.currentContext;
        if ([self.activeContexts count] > 0 || currentContext) {
            if (![self useMultipleActiveContexts])
                [self changeActiveIconImageColorTo:currentContext.iconColor];
            else if ([self.activeContexts count] == 1) {
                Context *singleContext = [[self.activeContexts allObjects] objectAtIndex:0];
                [self changeActiveIconImageColorTo:singleContext.iconColor];
            }
            barImage = sbImageActive;
        } else {
            barImage = sbImageInactive;
        }
    }

    [self setMenuBarImage:barImage];
}

- (void)setMenuBarImage:(NSImage *)image {
    // if the menu bar item has been hidden sbItem will have been released
    // and we should not attempt to update the image
    if (!sbItem) {
        return;
    }

    @try {
        [sbItem setImage:image];
    }
    @catch (NSException *exception) {
        DSLog(@"failed to set the menubar icon to %@ with error %@. Please alert ControlPlane Developers!", [image name], [exception reason]);
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

    if ([[NSUserDefaults standardUserDefaults] integerForKey:@"menuBarOption"] != CP_DISPLAY_ICON) {
        [self setStatusTitle:[self currentContextPath]];
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

- (void)updateMenuBarAndContextMenu {
    [self updateMenuBarImage];
    if ([[NSUserDefaults standardUserDefaults] integerForKey:@"menuBarOption"] != CP_DISPLAY_ICON) {
        if ([self useMultipleActiveContexts]) {
            /*int x=0;
             NSMutableString *_joinedContextPaths = [NSMutableString string]; //..shortcut for:  [[[NSMutableString alloc] initWithString:@""] autorelease];
             for (Context *context in self.activeContexts) {
                if (x++!=0) [_joinedContextPaths appendString: @" + "];
                [_joinedContextPaths appendString:context.name]; //[contextsDataSource pathFromRootTo:context.uuid]];
             }
             self.currentContextPath=_joinedContextPaths;*/
            NSSortDescriptor *sortKey=[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:TRUE];
            NSArray *keyArray=[NSArray arrayWithObject:sortKey];
            self.currentContextPath=[[self.activeContexts sortedArrayUsingDescriptors:keyArray] componentsJoinedByString:@" + "]; // sans context-paths, to conserve space. perhaps we'll add a pref to switch it on (above).
        }
        [self setStatusTitle:[self currentContextPath]];
    }

    // Update force context menu items (set if they are ticked)
    NSMenu *menu = [forceContextMenuItem submenu];
    for (NSMenuItem *item in [menu itemArray]) {
        NSString *rep = [item representedObject];
        if (rep && [contextsDataSource contextByUUID:rep]) {
            BOOL ticked = ([rep isEqualToString:self.currentContext.uuid]);
            [item setState:(ticked ? NSOnState : NSOffState)];
        }
    }
}

- (void)rebuildForceContextMenu {
	// Fill in 'Force context' submenu
	NSMenu *submenu = [[[NSMenu alloc] init] autorelease];
	for (Context *ctxt in [contextsDataSource orderedTraversal]) {
		NSMenuItem *item = [[[NSMenuItem alloc] init] autorelease];
		[item setTitle:[ctxt name]];
		[item setIndentationLevel:[ctxt.depth intValue]];
		[item setRepresentedObject:ctxt.uuid];
		[item setTarget:self];
        if ([self useMultipleActiveContexts]) {
            [item setAction:@selector(activateContextByMenuClick:)];
            [item setRepresentedObject:ctxt];
        }
        else
            [item setAction:@selector(forceSwitch:)];
        
		[submenu addItem:item];
        
		item = [[item copy] autorelease];
		[item setTitle:[NSString stringWithFormat:@"%@ (*)", [item title]]];
		[item setKeyEquivalentModifierMask:NSAlternateKeyMask];
		[item setAlternate:YES];
		[item setAction:@selector(forceSwitchAndToggleSticky:)];
		[submenu addItem:item];
	}

	[forceContextMenuItem setSubmenu:submenu];
}

- (void) updateActiveContextsMenuTitle {
    if ([self.activeContexts count] > 1) {
        self.activeContextsMenuHeader = NSLocalizedString(@"Active Contexts:", @"");
    } else {
        self.activeContextsMenuHeader = NSLocalizedString(@"Active Context:", @"");
    }
}

- (void) updateActiveContextsMenuList {
    NSArray *currentMenuItems = [sbMenu itemArray];
    
    // look for menu items tagged "99"
    for (NSMenuItem *menuItem in currentMenuItems) {
        if ([menuItem tag] == 99)
            [sbMenu removeItem:menuItem];
    }
    
    // insert all active contexts
    if ([self.activeContexts count] == 0) {
        NSMenuItem *currentContextMenuItem = [[[NSMenuItem alloc] initWithTitle:@"?" action:nil keyEquivalent:@""] autorelease];
        [currentContextMenuItem setTag:99];
        [currentContextMenuItem setIndentationLevel:1];
        [currentContextMenuItem setEnabled:NO];

        [sbMenu insertItem:currentContextMenuItem atIndex:1];
    }
    else {
        for (Context *context in self.activeContexts) {
            NSMenuItem *currentContextMenuItem = nil;

            if ([self.stickyActiveContexts containsObject:context]) {
                currentContextMenuItem = [[[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@*", context.name] action:@selector(deactivateContextByMenuClick:) keyEquivalent:@""] autorelease];
                
                [currentContextMenuItem setToolTip:NSLocalizedString(@"Context is Sticky, click to deactivate context", @"")];
            }
            else {
                currentContextMenuItem = [[[NSMenuItem alloc] initWithTitle:context.name action:@selector(deactivateContextByMenuClick:) keyEquivalent:@""] autorelease];
                [currentContextMenuItem setToolTip:NSLocalizedString(@"Click to deactivate context", @"")];
            }
            
            [currentContextMenuItem setTag:99];
            [currentContextMenuItem setIndentationLevel:1];
            [currentContextMenuItem setRepresentedObject:context];

            [sbMenu insertItem:currentContextMenuItem atIndex:1];
        }
    }
}

- (void)contextsChanged:(NSNotification *)notification {
#ifdef DEBUG_MODE
    DSLog(@"in contextChanged");
#endif

    [self rebuildForceContextMenu];

    Context *currentContext = self.currentContext;
    if (currentContext) {
        currentContext = [contextsDataSource contextByUUID:currentContext.uuid];
    }

	// Update current context
    dispatch_async(updatingQueue, ^{
        [self changeCurrentContextTo:currentContext];
    });

    self.forceOneFullUpdate = YES;

	// update other stuff?
}

#pragma mark Rule matching and Action triggering

- (NSArray *)getRulesThatMatchAndSetChangeFlag:(BOOL *)flag {
	NSArray *rules = self.rules;

#ifdef DEBUG_MODE
    DSLog(@"Rules list (%ld rules):\n%@", [rules count], rules);
#endif
	NSMutableArray *matchingRules = [NSMutableArray array];
    BOOL changed = NO;

	for (NSMutableDictionary *rule in rules) {
#ifdef DEBUG_MODE
        DSLog(@"checking rule %@", rule);
#endif
		RuleMatchStatusType isMatching = [evidenceSources ruleMatches:rule];
        if (isMatching == RuleDoesMatch) {
			[matchingRules addObject:rule];
        }

        NSNumber *recentStatus = rule[@"cachedStatus"];
        RuleMatchStatusType wasMatching = (recentStatus) ? ([recentStatus intValue]) : (RuleMatchStatusIsUnknown);
        if (wasMatching != isMatching) {
            rule[@"cachedStatus"] = @(isMatching);
            changed = YES;
        }
	}

    if (changed) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self willChangeValueForKey:@"activeRules"];
            [self didChangeValueForKey:@"activeRules"];
        });
    }

    *flag = changed;

	return matchingRules;
}


// (Private) in a new thread, execute Action immediately, growling upon failure
// performs an individual action called by an executeAction* method and on
// a new thread
- (void)doExecuteAction:(Action *)action {
	@autoreleasepool {
        NSString *errorString;
        BOOL success = [action execute:&errorString];
        [self decreaseActionsInProgress];

        if (!success) {
            NSString *title = NSLocalizedString(@"Failure", @"Growl message title");
            [CPNotifications postUserNotification:title withMessage:errorString];
        }
    }
}

// (Private) in a separate thread
// Parameter is an NSArray of actions
- (void)executeActionsFrom:(NSArray *)actions atIndexes:(NSIndexSet *)indexes {
    if ([indexes count] > 0) {
        // Aggregate notification messages for all actions
        NSString *title, *msg = [actions componentsAtIndexes:indexes joinedByString:@"\n* "];
        if ([indexes count] == 1) {
            title = NSLocalizedString(@"Performing Action", @"Growl message title");
        } else {
            title = NSLocalizedString(@"Performing Actions", @"Growl message title");
            msg = [@"* " stringByAppendingString:msg];
        }

        [CPNotifications postUserNotification:title withMessage:msg];

        [actions enumerateObjectsAtIndexes:indexes options:0 usingBlock:^(Action *action, NSUInteger idx, BOOL *stop) {
            [self increaseActionsInProgress];
            [NSThread detachNewThreadSelector:@selector(doExecuteAction:) toTarget:self withObject:action];
        }];
    }
}

- (void)executeOrQueueActions:(NSArray *)actions {
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];

    [actions enumerateObjectsUsingBlock:^(Action *action, NSUInteger idx, BOOL *stop) {
        if (screenLocked && [[action class] shouldWaitForScreenUnlock]) {
            [screenLockActionQueue addObject:action];
            return;
        }
        if (screenSaverRunning && [[action class] shouldWaitForScreensaverExit]) {
            [screenSaverActionQueue addObject:action];
            return;
        }
        [indexes addIndex:idx];
    }];

    [self executeActionsFrom:actions atIndexes:indexes];
}

- (void)executeActions:(NSArray *)actions withDelay:(NSTimeInterval)delay {
    if (delay == 0.0) {
        [self executeOrQueueActions:actions];
        return;
    }

    [self increaseActionsInProgress];
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC));
    dispatch_after(popTime, concurrentActionQueue, ^{
        @autoreleasepool {
            [self executeOrQueueActions:actions];
            [self decreaseActionsInProgress];
        }
    });
}

// (Private) This will group the growling together.
// The first parameter MUST be an array of Action objects ORDERED in the appropriate way.
- (void)scheduleOrderedActions:(NSArray *)actions usingDelayProvider:(double (^)(Action *action))getDelay {
	static const double batchThreshold = 0.25;		// maximum grouping interval size
    
	NSMutableArray *batch = nil;
    NSTimeInterval batchDelay = 0.0, maxBatchDelay = 0.0;
	for (Action *action in actions) {
		const double actionDelay = getDelay(action);
        if (batch) {
            if (actionDelay < maxBatchDelay) {
                [batch addObject:action];
                continue;
            }
            
            // Completed a batch
            [self executeActions:batch withDelay:batchDelay];
		}
        
        // Start a new batch with the current action
		batch = [NSMutableArray arrayWithObject:action];
        batchDelay = actionDelay;
        maxBatchDelay = actionDelay + batchThreshold;
	}
    
	// Final batch
	if ([batch count] > 0) {
        [self executeActions:batch withDelay:batchDelay];
	}
}

- (void)scheduleActions:(NSMutableArray *)actions
     usingReverseDelays:(BOOL)areReversed
               maxDelay:(NSTimeInterval *)maxDelay {
    
    double maxDelayValue = 0.0;
    
	if ([actions count] > 0) {
        if (!areReversed) {
            // Sort by delay (ascending order)
            [actions sortUsingSelector:@selector(compareDelay:)];
            
            maxDelayValue = [[[actions lastObject] valueForKey:@"delay"] doubleValue];
            
            [self scheduleOrderedActions:actions usingDelayProvider:^(Action *action) {
                return [[action valueForKey:@"delay"] doubleValue];
            }];
        } else {
            // Sort by delay (descending order)
            [actions sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                return [obj2 compareDelay:obj1]; // reverse comparison
            }];
            
            maxDelayValue = [[actions[0] valueForKey:@"delay"] doubleValue];
            
            [self scheduleOrderedActions:actions usingDelayProvider:^(Action *action) {
                return (maxDelayValue - [[action valueForKey:@"delay"] doubleValue]);
            }];
        }
    }
    
    if (maxDelay) {
        *maxDelay = maxDelayValue;
    }
}

- (void)enumerateEnabledActionsForContext:(Context *)ctxt
                                 on:(NSString *)triggerId
                         usingBlock:(void (^)(NSDictionary *))block {

    NSString *contextUUID = [ctxt uuid];
	NSArray *actions = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Actions"];

	for (NSDictionary *action in actions) {
		if ([action[@"context"] isEqualToString:contextUUID] && [action[@"enabled"] boolValue]) {
            NSString *when = action[@"when"];
            if ([when isEqualToString:triggerId] || [when isEqualToString:@"Both"]) {
                block(action);
            }
        }
	}
}

- (void)triggerArrivalActionsOnWalk:(NSArray *)walk {
    NSMutableArray *arrivalActions = [NSMutableArray array];
    for (Context *ctxt in walk) {
        [self enumerateEnabledActionsForContext:ctxt on:@"Arrival" usingBlock:^(NSDictionary *actionParams) {
            Action *action = [Action actionFromDictionary:actionParams];
            if (!action) {
                DSLog(@"ERROR: %@",
                      NSLocalizedString(@"ControlPlane attempted to perform action it doesn't know about,"
                                        " you probably have a configured action that is no longer (or not yet)"
                                        " supported by ControlPlane",
                                        "ControlPlane was told to run an action that doesn't actually exist"));
                return;
            }

            [arrivalActions addObject:action];
        }];
    }

    [self scheduleActions:arrivalActions usingReverseDelays:NO maxDelay:NULL];
}

- (void)triggerDepartureActionsOnWalk:(NSArray *)walk usingReverseDelays:(BOOL)areDelaysReversed {
    NSMutableArray *departureActions = [NSMutableArray array];
    for (Context *ctxt in walk) {
        [self enumerateEnabledActionsForContext:ctxt on:@"Departure" usingBlock:^(NSDictionary *actionParams) {
            Action *action = [Action actionFromDictionary:actionParams];
            if (!action) {
                DSLog(@"ERROR: %@",
                      NSLocalizedString(@"ControlPlane attempted to perform action it doesn't know about,"
                                        " you probably have a configured action that is no longer (or not yet)"
                                        " supported by ControlPlane",
                                        "ControlPlane was told to run an action that doesn't actually exist"));
                return;
            }

            [departureActions addObject:action];
        }];
    }
    
    NSTimeInterval maxDelay = 0.0;
    [self scheduleActions:departureActions usingReverseDelays:areDelaysReversed maxDelay:&maxDelay];
    
	// Finally, we have to sleep this thread, so we don't return until we're ready to change contexts.
    if (areDelaysReversed && (maxDelay > 0.0)) {
        DSLog(@"Delay switching context for %.2f secs to let all departure actions start", (float) maxDelay);
        [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:maxDelay]];
    }
}

#pragma mark -
#pragma mark Screen Saver Monitoring

- (void) setScreenSaverActive:(NSNotification *) notification {
    [self setScreenSaverRunning:YES];
    DSLog(@"Screen saver is running");
}

- (void) setScreenSaverInActive:(NSNotification *) notification {
    [self setScreenSaverRunning:NO];
    DSLog(@"Screen saver is not running");

    dispatch_async(updatingQueue, ^{
        if ([screenSaverActionQueue count] > 0) {
            NSArray *queue = screenSaverActionQueue;
            screenSaverActionQueue = [[NSMutableArray alloc] init];
            [self executeOrQueueActions:queue];
            [queue release];
        }
    });
}

#pragma mark -
#pragma mark Screen Lock Monitoring

- (void) setScreenLockActive:(NSNotification *) notification {
    [self setScreenLocked:YES];
    DSLog(@"Screen lock becoming active");
}

- (void) setScreenLockInActive:(NSNotification *) notification {
    [self setScreenLocked:NO];
    DSLog(@"Screen lock becoming inactive");

    dispatch_async(updatingQueue, ^{
        if ([screenLockActionQueue count] > 0) {
            NSArray *queue = screenLockActionQueue;
            screenLockActionQueue = [[NSMutableArray alloc] init];
            [self executeOrQueueActions:queue];
            [queue release];
        }
    });
}


#pragma mark -
#pragma mark Context switching

- (NSString *)currentContextName {
    Context *currentContext = self.currentContext;
    return (currentContext) ? (currentContext.name) : (@"?");
}

- (void) activateContext:(Context *) context {
    [self.activeContexts addObject:context];
    DSLog(@"Triggering arrival actions, if any, for '%@'", context.name);
    [self triggerArrivalActionsOnWalk:[NSArray arrayWithObject:context]];
    [self updateActiveContextsMenuTitle];
    [self updateActiveContextsMenuList];
}

- (void) deactivateContext:(Context *) context {
    if (context != nil) {
        [self.activeContexts removeObject:context];
        DSLog(@"Triggering departure actions, if any, for '%@'", context.name);
        [self triggerDepartureActionsOnWalk:[NSArray arrayWithObject:context] usingReverseDelays:NO];
    }
    [self updateActiveContextsMenuTitle];
    [self updateActiveContextsMenuList];
}

- (void) activateContextByMenuClick:(NSMenuItem *) sender {
    //[self triggerArrivalActionsOnWalk:[NSArray arrayWithObject:[contextsDataSource contextByName:sender.title]]];
    if (forcedContextIsSticky)
        [self.stickyActiveContexts addObject:sender.representedObject];
    
    [self activateContext:sender.representedObject];
    
}

- (void) deactivateContextByMenuClick:(NSMenuItem *) sender {
    //[self triggerDepartureActionsOnWalk:[NSArray arrayWithObject:[contextsDataSource contextByName:sender.title]]];

    if (forcedContextIsSticky && [self.stickyActiveContexts containsObject:sender.representedObject])
        [self.stickyActiveContexts removeObject:sender.representedObject];
    
    [self deactivateContext:sender.representedObject];
    
    
}

- (void)changeCurrentContextTo:(Context *)context {
    NSString *contextPath = (context) ? [contextsDataSource pathFromRootTo:context.uuid] : (@"?");

    self.currentContext = context;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self willChangeValueForKey:@"currentContextName"];
        [self didChangeValueForKey:@"currentContextName"];
    });

    self.currentContextPath = contextPath;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateMenuBarAndContextMenu];
    });
}

- (void)performTransitionToContext:(Context *)context
                 triggeredManually:(BOOL)isManuallyTriggered {
#if DEBUG_MODE
    // Create context named 'Developer Crash' and CP will crash when moving to it if using a DEBUG build
    // Allows you to test QuincyKit
    if ([context.name isEqualToString:@"Developer Crash"]) {
        kill( getpid(), SIGABRT );
    }
#endif
    
    if (self.currentContext != nil) {
        [self.activeContexts removeObject:[contextsDataSource contextByUUID:self.currentContext.uuid]];
    }
    
    [self.activeContexts addObject:context];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateActiveContextsMenuList];
        [self updateActiveContextsMenuTitle];
    });
    
    NSArray *walks = [contextsDataSource walkFrom:self.currentContext.uuid to:context.uuid];
	NSArray *leavingWalk = walks[0], *enteringWalk = walks[1];
    
    if ([leavingWalk count] > 0) {
        DSLog(@"Triggering departure actions, if any, for '%@'", [self currentContextName]);
        
        // Originally CP was implemented so that deactivating the current (single) active context
        // was done with departure actions being triggered based on their _reverse_ delays.
        // We now have to keep supporting that original logic for backward compatibility.
        [self triggerDepartureActionsOnWalk:leavingWalk usingReverseDelays:YES];
    }
    
    [self changeCurrentContextTo:context];
    [self postNotificationsOnContextTransitionWhenForcedByUserIs:isManuallyTriggered];
    
    if ([enteringWalk count] > 0) {
        DSLog(@"Triggering arrival actions, if any, for '%@'", [self currentContextName]);
        [self triggerArrivalActionsOnWalk:enteringWalk];
    }
}

- (void)postNotificationsOnContextTransitionWhenForcedByUserIs:(BOOL)isManuallyTriggered {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"EnableGrowl"]) {
        NSString *msg = [self getMesssageForChangingToContextWhenForcedByUserIs:isManuallyTriggered];
        [CPNotifications postUserNotification:NSLocalizedString(@"Activating Context", @"Growl message title")
                                  withMessage:msg];
    }
    
    // Notify subscribed apps
    NSDistributedNotificationCenter *dnc = [NSDistributedNotificationCenter defaultCenter];
    NSString *notificationObject = [[NSBundle mainBundle] bundleIdentifier];
    [dnc postNotificationName:[notificationObject stringByAppendingString:@".ContextChanged"]
                       object:notificationObject
                     userInfo:@{ @"context": self.currentContextPath }
           deliverImmediately:YES];
}

- (NSString *)getMesssageForChangingToContextWhenForcedByUserIs:(BOOL)isManuallyTriggered {
    NSString *msgSuffix = nil;
    if (isManuallyTriggered) {
        msgSuffix = NSLocalizedString(@"(forced)", @"Used when force-switching to a context");
    } else {
        NSNumber *confidence = self.currentContext.confidence;
        NSString *percentage = [[SharedNumberFormatter percentStyleFormatter] stringFromNumber:confidence];

        NSString *suffixFmt = NSLocalizedString(@"with confidence %@", @"Appended to a context-change notification");
        msgSuffix = [NSString stringWithFormat:suffixFmt, percentage];
    }

    NSString *fmt = NSLocalizedString(@"Activating context '%@' %@.",
                                      @"First parameter is the context name, second parameter is the confidence value,"
                                      " or 'as default context'");
	return [NSString stringWithFormat:fmt, self.currentContextPath, msgSuffix];
}


#pragma mark -
#pragma mark Force context switching

- (void)forceSwitch:(id)sender {
	Context *ctxt = nil;
	
	if ([sender isKindOfClass:[Context class]]) {
		ctxt = (Context *) sender;
    } else {
		ctxt = [contextsDataSource contextByUUID:[sender representedObject]];
    }
	
	DSLog(@"Going to '%@'", [ctxt name]);

	// Selecting any context in the force-context menu deselects the 'stick forced contexts' item,
	// so we force it to be correct here.
	int state = forcedContextIsSticky ? NSOnState : NSOffState;
    [self.stickForcedContextMenuItem setState:state];

    [self increaseActionsInProgress];
    dispatch_async(updatingQueue, ^{
        [self performTransitionToContext:ctxt triggeredManually:YES];
        
        if (!forcedContextIsSticky) {
            self.forceOneFullUpdate = YES;
            [self restartSwitchSmoothing];
        }
        [self decreaseActionsInProgress];
    });
}

- (void)setStickyBit:(NSNotification *) notification {
    if (![self stickyContext]) {
        [self toggleSticky:self.stickForcedContextMenuItem];
    }
}

- (void)unsetStickyBit:(NSNotification *) notification {
    if ([self stickyContext]) {
        [self toggleSticky:self.stickForcedContextMenuItem];
    }
}

- (IBAction)toggleSticky:(id)sender {
	BOOL oldValue = forcedContextIsSticky;
	forcedContextIsSticky = !oldValue;

  	[sender setState:(forcedContextIsSticky ? NSOnState : NSOffState)];

    if (!forcedContextIsSticky) {
        [self setForceOneFullUpdate:YES];
        [self restartSwitchSmoothing];
        [self.stickyActiveContexts removeAllObjects];
    }
}

- (void)forceSwitchAndToggleSticky:(id)sender {
	[self toggleSticky:sender];
	[self forceSwitch:sender];
}


#pragma mark -
#pragma mark Updating queue stuff

// this method is the meat of ControlPlane, it is the engine that
// determines if matching rules add up to the required confidence level
// and initiates a switch from one context to another

// TODO: allow multiple contexts to be active at once
- (void)doUpdateForReal {
    BOOL changed = NO;
    NSArray *matchingRules = [self getRulesThatMatchAndSetChangeFlag:&changed];
#ifdef DEBUG_MODE
    DSLog(@"Rules that match: %@", matchingRules);
#endif
    
    if (!changed && (smoothCounter == 0) && !self.forceOneFullUpdate) {
#ifdef DEBUG_MODE
        DSLog(@"Same rule are matching as on previous update. No further actions required.");
#endif
        return;
    }
    self.forceOneFullUpdate = NO;
    
    // of the configured contexts, which ones have rule hits?
    NSMutableDictionary *guesses = [self getGuessesForRules:matchingRules];
    
    // Don't include the default context yet because
    // under multiple active contexts it'll show as active
    // when it shouldn't (default context always meets minimum
    // confidence required)
    if (![self useMultipleActiveContexts])
        [self applyDefaultContextTo:guesses];
    
    DSLog(@"Context guesses: %@", guesses);
    
    [contextsDataSource updateConfidencesFromGuesses:guesses];
    
    if (forcedContextIsSticky) { // prevent switching contexts when the current one is forced and sticky
        return;
    }
    
    if ([self useMultipleActiveContexts]) {
        [self changeActiveContextsBasedOnGuesses:guesses];
    } else {
        // use the older style of context matching
        // of the guesses, which one has the highest confidence rating?
        Context *guessContext = [self getMostConfidentContext:guesses];
        
        if (guessContext && [self guessMeetsConfidenceRequirement:guessContext]) {
            [self increaseActionsInProgress];
            dispatch_async(updatingQueue, ^{
                [self performTransitionToContext:guessContext triggeredManually:NO];
                [self decreaseActionsInProgress];
            });
        }
    }
}

#pragma mark Multiple Active Contexts
/**
 * Multiple Active Context Routine
 */
- (void)changeActiveContextsBasedOnGuesses:(NSMutableDictionary *)guesses {
    NSMutableSet *newActiveContexts = [NSMutableSet set];
    
    double minConfidence = [[NSUserDefaults standardUserDefaults] floatForKey:@"MinimumConfidenceRequired"];
    [guesses enumerateKeysAndObjectsUsingBlock:^(id key, NSNumber *confidence, BOOL *stop) {
        if ([confidence doubleValue] < minConfidence) {
#ifdef DEBUG_MODE
            DSLog(@"%@ does not meet requirements", [contextsDataSource contextByUUID:key].name);
#endif
            return;
        }
        
        Context *context = [contextsDataSource contextByUUID:key];
#ifdef DEBUG_MODE
        DSLog(@"%@ meets requirements", context.name);
#endif
        [newActiveContexts addObject:context];
    }];
    
    // apply the default context *only* if no other contexts apply
    // and the user has enabled the option
    if ([self useDefaultContext] && ([self.activeContexts count] == 0 || [self defaultContextIsActive])) {
        [self applyDefaultContextTo:guesses];
        [contextsDataSource updateConfidencesFromGuesses:guesses];
        [newActiveContexts addObject:[self getMostConfidentContext:guesses]];
    }
    
#ifdef DEBUG_MODE
    DSLog(@"Previously active %@", self.activeContexts);
    DSLog(@"Activating before %@", newActiveContexts);
#endif
    
    // of the currently active contexts, which ones shouldn't be?
    NSMutableSet *deactivate = [NSMutableSet setWithSet:self.activeContexts];
    [deactivate minusSet:newActiveContexts];
    
    // but don't remove sticky active contexts
    [deactivate minusSet:self.stickyActiveContexts];
    
    // now remove contexts that are already active
    NSMutableSet *activate = [NSMutableSet setWithSet:newActiveContexts];
    [activate minusSet:self.activeContexts];
    
    // Switch smoothing for multiple active contexts.
    // It ensures that a context to be activated/deactivated survives two consequtive updates.
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"EnableSwitchSmoothing"]) {
        // switch smoothing for activated contexts
        NSMutableSet *newCandidatesToActivate = [NSMutableSet setWithSet:activate];
        [newCandidatesToActivate minusSet:self.candidateContextsToActivate];
        
        [activate intersectSet:self.candidateContextsToActivate];
        
        [self.candidateContextsToActivate setSet:newCandidatesToActivate];
#ifdef DEBUG_MODE
        DSLog(@"Candidates for activation %@", self.candidateContextsToActivate);
#endif
        
        // switch smoothing for deactivated contexts
        NSMutableSet *newCandidatesToDeactivate = [NSMutableSet setWithSet:deactivate];
        [newCandidatesToDeactivate minusSet:self.candidateContextsToDeactivate];
        
        [deactivate intersectSet:self.candidateContextsToDeactivate];
        
        [self.candidateContextsToDeactivate setSet:newCandidatesToDeactivate];
#ifdef DEBUG_MODE
        DSLog(@"Candidates for deactivation %@", self.candidateContextsToDeactivate);
#endif
        
        if (([newCandidatesToActivate count] == 0) && ([newCandidatesToDeactivate count] == 0)) {
            smoothCounter = 0;
        } else {
            smoothCounter = 1;
        }
    }
    
    if (([activate count] == 0) && ([deactivate count] == 0)) { // no change
        return;
    }
    
	if ([activate count] > 0) {
		NSMutableSet *alreadyActiveWalks = [NSMutableSet set];
		NSMutableSet *activateWalks = [NSMutableSet set];
		for (Context *context in self.activeContexts)
			[alreadyActiveWalks addObjectsFromArray:[contextsDataSource walkToRoot:context.uuid]];
		for (Context *context in activate) {
			[activateWalks addObjectsFromArray:[contextsDataSource walkToRoot:context.uuid]];
			DSLog(@"Activating context: '%@'", [contextsDataSource pathFromRootTo:context.uuid]);
		}
        [activateWalks minusSet:alreadyActiveWalks];
        [self triggerArrivalActionsOnWalk:[activateWalks allObjects]];
	}
    
	if ([deactivate count] > 0) {
		NSMutableSet *deactivateWalks = [NSMutableSet set];
		for (Context *context in deactivate) {
			[deactivateWalks addObjectsFromArray:[contextsDataSource walkToRoot:context.uuid]];
			DSLog(@"Deactivating context: '%@'", [contextsDataSource pathFromRootTo:context.uuid]);
		}
		[self triggerDepartureActionsOnWalk:[deactivateWalks allObjects] usingReverseDelays:NO];
	}
    
    [self.activeContexts minusSet:deactivate];
    [self.activeContexts unionSet:activate];
    
#ifdef DEBUG_MODE
    DSLog(@"Currently active %@", self.activeContexts);
#endif
    // immediately re-evaluate guesses if we've deactivated all contexts
    // and use default context option is on
    if ([self useDefaultContext] && [self.activeContexts count] == 0) {
        [self changeActiveContextsBasedOnGuesses:guesses];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateActiveContextsMenuTitle];
        [self updateActiveContextsMenuList];
        [self updateMenuBarAndContextMenu];
    });
}

// If configured to use a default context, add it here
// and set the confidence value to exactly the minimum required
- (void)applyDefaultContextTo:(NSMutableDictionary *)guesses {
    
    if ([self useDefaultContext]) {
        NSString *uuid = [self getDefaultContext];
        const double minConfidence = (double) [[NSUserDefaults standardUserDefaults] floatForKey:@"MinimumConfidenceRequired"];
        
        NSNumber *guessConfidence = guesses[uuid];
        if (!guessConfidence || ([guessConfidence doubleValue] < minConfidence)) {
            guesses[uuid] = @(minConfidence);
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

		const int base_depth = [((Context *) currentContextTree[0]).depth intValue];
        const double currentRuleConfidence = [currentRule[@"confidence"] doubleValue];

		for (Context *currentContext in currentContextTree) {
			NSString *uuidOfCurrentContext = [currentContext uuid];

            // seed unconfidenceValue with what we've calcuated so far
			NSNumber *unconfidenceValue = guesses[uuidOfCurrentContext];

            // if the unconfidenceValue isn't set initilialize it to a sane default
            if (!unconfidenceValue) {
				unconfidenceValue = @1.0;
            }

            // account for the amount of confidence this matching rule affects the guess
			const int depth = [currentContext.depth intValue];
			double mult = 1.0 - (0.03 * (depth - base_depth)); // decay
			mult *= currentRuleConfidence;
			unconfidenceValue = @([unconfidenceValue doubleValue] * (1.0 - mult));

#ifdef DEBUG_MODE
			DSLog(@"Crediting '%@' (d=%d|%d) with %.5f\t-> %@", [currentContext name], depth, base_depth, mult, unconfidenceValue);
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
 * Finds the context for most confidence guess
 * 
 * @param NSDictionary list of guesses
 * @return Context for the most confident guess
 */
- (Context *)getMostConfidentContext:(NSDictionary *)guesses {
	__block NSString *guessUUID = nil;
	__block double guessConf = -1.0; // guaranteed to be less than any actual confidence value

    // Finds the context with the highest confidence rating but not necessarily
    // one that satisfies the minimum confidence
    [guesses enumerateKeysAndObjectsUsingBlock:^(NSString *uuid, NSNumber *conf, BOOL *stop) {
	 	const double confindence = [conf doubleValue];
		if (confindence > guessConf) {
            *stop = (confindence >= 1.0);
			guessConf = confindence;
			guessUUID = uuid;
		}
    }];

    return (guessUUID) ? ([contextsDataSource contextByUUID:guessUUID]) : (nil);
}

/**
 * Decides if a given guess can become active
 */
- (BOOL)guessMeetsConfidenceRequirement:(Context *)guessContext {
    NSString *guessUUID = guessContext.uuid;
    NSNumber *guessConf = guessContext.confidence;

    DSLog(@"Checking '%@' (%@) with confidence %@", guessContext.name, guessUUID, guessConf);

    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];

    // this decides if the guess is confident enough
	if ([guessConf doubleValue] < [standardUserDefaults floatForKey:@"MinimumConfidenceRequired"]) {
#ifdef DEBUG_MODE
        DSLog(@"Guess of '%@' isn't confident enough: only %@.", guessContext.name, guessConf);
#endif
        [self restartSwitchSmoothing];
        return NO;
	}

    
	if ([guessUUID isEqualToString:self.currentContext.uuid]) {
#ifdef DEBUG_MODE
		DSLog(@"Guessed '%@' (with confidence %@); already there.", guessContext.name, guessConf);
#endif
        [self restartSwitchSmoothing];
		return NO;
	}
    

    // the smoothing feature is designed to prevent ControlPlane from flapping between contexts
	if ([standardUserDefaults boolForKey:@"EnableSwitchSmoothing"]) {
		if ((smoothCounter > 0) && [self.candidateContextUUID isEqualToString:guessUUID]) {
            --smoothCounter;
		} else {
			smoothCounter = [standardUserDefaults integerForKey:@"SmoothSwitchCount"];	// Make this customisable?
            self.candidateContextUUID = guessUUID;
        }

        if (smoothCounter > 0) {
#ifdef DEBUG_MODE
            DSLog(@"Switch smoothing kicking in... ('%@' != '%@')", [self currentContextName], guessContext.name);
#endif
            return false;
        }

        [self restartSwitchSmoothing];
	}

    return true;
}

- (void)restartSwitchSmoothing {
    smoothCounter = 0;
    self.candidateContextUUID = nil;
    [self.candidateContextsToActivate removeAllObjects];
    [self.candidateContextsToDeactivate removeAllObjects];
}

- (void)goingToSleep:(id)arg {
    if (self.goingToSleep) {
        DSLog(@"WARNING: ControlPlane has received more than one notification in row about system sleep.");
        return;
    }
    [self setGoingToSleep:YES];
    
    [self suspendRegularUpdates];
    
    // clear the queued actions on sleep
    // in case the machine woke up but the screen saver
    // was never exited or the screen was never unlocked
    // but then the machine went back to sleep
    dispatch_async(updatingQueue, ^{
        [screenSaverActionQueue removeAllObjects];
        [screenLockActionQueue removeAllObjects];
    });
}

- (void)wakeFromSleep:(id)arg {
    if (!self.goingToSleep) {
        DSLog(@"WARNING: ControlPlane has received more than one notification in row about system wake-up.");
        return;
    }
    [self setGoingToSleep:NO];
    
    [self restartSwitchSmoothing];
    [self resumeRegularUpdatesWithDelay:(2 * NSEC_PER_SEC)];
}


//////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark -
#pragma mark NSApplication delegates

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
    [self showInStatusBar:self];
    [self startOrStopHidingFromStatusBar];
	return YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self suspendRegularUpdates];
    
	NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    if ([standardUserDefaults boolForKey:@"EnablePersistentContext"]) {
		[standardUserDefaults setValue:self.currentContext.uuid forKey:@"PersistentContext"];
	}
    
    [evidenceSources stopAllRunningEvidenceSources];
}

- (void) showMainApplicationWindow {
	[prefsWindow makeFirstResponder:nil];
}

#pragma mark NSUserDefaults notifications

- (void)userDefaultsChanged:(NSNotification *)notification {
    [self startOrStopHidingFromStatusBar];
    [self updateMenuBarImage];

    if ([[NSUserDefaults standardUserDefaults] integerForKey:@"menuBarOption"] == CP_DISPLAY_ICON) {
        [self setStatusTitle:nil];
    } else {
        [self setStatusTitle:[self currentContextPath]];
    }

#ifndef DEBUG_MODE
    // Force write of preferences
    [[NSUserDefaults standardUserDefaults] synchronize];
#endif

    self.forceOneFullUpdate = YES; // force updating (e.g. the default context settings could change)

    if (!goingToSleep) {
        int64_t currentUpdateInterval = [[self class] getUpdateInterval];
        if (updateInterval != currentUpdateInterval) {
            updateInterval  = currentUpdateInterval;
            [self shiftRegularUpdatesToStartAt:dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC)];
        }
    }
}

#pragma mark -
#pragma mark Evidence source change handling
- (void)evidenceSourceDataDidChange:(NSNotification *)notification {
    dispatch_queue_t mainQueue = dispatch_get_main_queue();
    if (dispatch_get_current_queue() != mainQueue) {
        dispatch_async(mainQueue, ^{
            [self evidenceSourceDataDidChange:notification];
        });
        return;
    }
    
#ifdef DEBUG_MODE
    DSLog(@"**** TRIGGERING UPDATE BECAUSE EVIDENCE SOURCE DATA CHANGED ****");
#endif
    [self shiftRegularUpdatesToStartAt:dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC)];
}


#pragma mark -
#pragma mark CPController Updating Queue and Timer

const int64_t UPDATING_TIMER_LEEWAY = (int64_t) (0.5 * NSEC_PER_SEC);

+ (int64_t)getUpdateInterval {
	NSTimeInterval interval = [[NSUserDefaults standardUserDefaults] floatForKey:@"UpdateInterval"];
    if (interval < 0.1) {
        interval = 0.1;
    }
    return (int64_t) (interval * NSEC_PER_SEC);
}

- (BOOL)doInitUpdatingQueue {
    updatingQueue = dispatch_queue_create("com.dustinrue.ControlPlane.UpdateQueue", DISPATCH_QUEUE_SERIAL);
    if (!updatingQueue) {
        DSLog(@"Failed to create a GCD queue");
        return NO;
    }
    concurrentActionQueue = dispatch_queue_create("com.dustinrue.ControlPlane.ActionQueue", DISPATCH_QUEUE_CONCURRENT);
    if (!concurrentActionQueue) {
        DSLog(@"Failed to create a GCD queue");
        return NO;
    }

    updatingTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, updatingQueue);
    if (!updatingTimer) {
        DSLog(@"Failed to create a GCD timer source");
        return NO;
    }
    dispatch_source_set_event_handler(updatingTimer, ^{
#ifdef DEBUG_MODE
        DSLog(@"**** DOING UPDATE LOOP BY TIMER ****");
#endif
        [self doUpdate];
    });

    updateInterval = [[self class] getUpdateInterval];
    dispatch_source_set_timer(updatingTimer, DISPATCH_TIME_NOW, updateInterval, UPDATING_TIMER_LEEWAY);

    return YES;
}

- (void)doReleaseUpdatingQueue {
    if (updatingTimer) {
        dispatch_source_cancel(updatingTimer);
        dispatch_release(updatingTimer);
    }
    if (concurrentActionQueue) {
        dispatch_release(concurrentActionQueue);
    }
    if (updatingQueue) {
        dispatch_release(updatingQueue);
    }
}

- (void)suspendRegularUpdates {
    DSLog(@"Suspending regular updates.");
    dispatch_suspend(updatingTimer);
}

- (void)resumeRegularUpdates {
    DSLog(@"Resuming regular updates.");
    dispatch_resume(updatingTimer);
}

- (void)resumeRegularUpdatesWithDelay:(int64_t)nanoseconds {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, nanoseconds), dispatch_get_main_queue(), ^{
        DSLog(@"Resuming regular updates.");
        dispatch_resume(updatingTimer);
    });
}

- (void)shiftRegularUpdatesToStartAt:(dispatch_time_t)time {
    dispatch_source_set_timer(updatingTimer, time, updateInterval, UPDATING_TIMER_LEEWAY);
}

- (void)doUpdate {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Enabled"]) {
        @autoreleasepool {
            [self doUpdateForReal];
        }
    }
}

- (void)forceUpdate {
    [self increaseActionsInProgress];
    dispatch_async(updatingQueue, ^{
        [self doUpdate];
        [self decreaseActionsInProgress];
    });
}

- (BOOL) useMultipleActiveContexts {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"AllowMultipleActiveContexts"];
}

- (BOOL) useDefaultContext {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"UseDefaultContext"];
}

- (NSString *) getDefaultContext {
    return [[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultContext"];
}

- (BOOL) defaultContextIsActive {
    return [self.activeContexts containsObject:[self getDefaultContext]];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    switch ([keyPath isEqualToString:@"AllowMultipleActiveContexts"]) {
        case YES:
            self.currentContext = nil;
            [self.stickyActiveContexts removeAllObjects];
            [self changeActiveContextsBasedOnGuesses:[NSMutableDictionary dictionary]];
            [self.activeContexts removeAllObjects];
            [self forceOneFullUpdate];
            break;
            
        default:
            break;
    }
}
@end
