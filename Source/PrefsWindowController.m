//
//  Modified by VladimirTechMan (Vladimir Beloborodov) on 21 May 2014. Switching the code to ARC.
//
//  IMPORTANT: This code is intended to be compiled for the ARC mode
//

#import "AboutPanel.h"
#import "Action.h"
#import "DSLogger.h"
#import "PrefsWindowController.h"
#import "NSTimer+Invalidation.h"
#import "RuleType.h"

// This is here to avoid IB's problem with unknown base classes
@interface ActionTypeHelpTransformer : NSValueTransformer {}
@end
@interface DelayValueTransformer : NSValueTransformer {}
@end
@interface LocalizeTransformer : NSValueTransformer {}
@end
@interface WhenLocalizeTransformer : NSValueTransformer {}
@end
@interface ContextNameTransformer : NSValueTransformer {
	ContextsDataSource *contextsDataSource;
}
@end
@interface RuleStatusResultTransformer : NSValueTransformer
@end


@implementation ActionTypeHelpTransformer

+ (Class)transformedValueClass { return [NSString class]; }

+ (BOOL)allowsReverseTransformation { return NO; }

- (id)transformedValue:(id)theValue
{
	return [Action helpTextForActionOfType:(NSString *) theValue];
}

@end

@implementation DelayValueTransformer

+ (Class)transformedValueClass { return [NSString class]; }

+ (BOOL)allowsReverseTransformation { return YES; }

- (id)transformedValue:(id)theValue
{
	if (theValue == nil)
		return 0;
	int value = [theValue intValue];

	if (value == 0)
		return NSLocalizedString(@"None", @"Delay value to display for zero seconds");
	else if (value == 1)
		return NSLocalizedString(@"1 second", @"Delay value; number MUST come first");
	else
		return [NSString stringWithFormat:NSLocalizedString(@"%d seconds", "Delay value for >= 2 seconds; number MUST come first"), value];
}

- (id)reverseTransformedValue:(id)theValue
{
	NSString *value = (NSString *) theValue;
	double res;

	if (!value || [value isEqualToString:NSLocalizedString(@"None", @"Delay value to display for zero seconds")])
		res = 0.0;
	else
		res = [value doubleValue];

	return @(res);
}

@end

@implementation LocalizeTransformer

+ (Class)transformedValueClass { return [NSString class]; }

+ (BOOL)allowsReverseTransformation { return NO; }

- (id)transformedValue:(id)theValue
{
	return NSLocalizedString((NSString *) theValue, @"");
}

@end

// XXX: Yar... shouldn't really need this!
@implementation WhenLocalizeTransformer

+ (Class)transformedValueClass { return [NSString class]; }

+ (BOOL)allowsReverseTransformation { return NO; }

- (id)transformedValue:(id)theValue
{
	NSString *inc = [(NSString *) theValue lowercaseString];
	NSString *eng_str;
	// HACK: this should be sorted out nicer
	if ([inc isEqualToString:@"both"])
		eng_str = (NSString *) theValue;
	else
		eng_str = [NSString stringWithFormat:@"On %@", inc];

	return NSLocalizedString(eng_str, @"");
}

@end

@implementation ContextNameTransformer

+ (Class)transformedValueClass { return [NSString class]; }

+ (BOOL)allowsReverseTransformation { return NO; }

- (id)init:(ContextsDataSource *)dataSource
{
	if (!(self = [super init]))
		return nil;
	contextsDataSource = dataSource;
	return self;
}

- (id)transformedValue:(id)theValue
{
	return [contextsDataSource pathFromRootTo:theValue];
}

@end

@implementation RuleStatusResultTransformer

+ (Class)transformedValueClass { return [NSString class]; }

+ (BOOL)allowsReverseTransformation { return NO; }

- (id)transformedValue:(id)theValue {
    RuleMatchStatusType status = (theValue) ? ([theValue intValue]) : (RuleMatchStatusIsUnknown);
    if (status == RuleMatchStatusIsUnknown) {
        return  @"?";
    }
    return (status == RuleDoesMatch) ? (@"\u2713") : (@"");
}

@end

#pragma mark -

@interface PrefsWindowController ()

@property (nonatomic,strong) NSDate *logBufferUnchangedSince;

- (void)doAddRule:(NSDictionary *)dict;
- (void)doEditRule:(NSDictionary *)dict;
- (void)updateLogBuffer:(NSTimer *)timer;
- (void)onPrefsWindowClose:(NSNotification *)notification;

@end

#pragma mark -

@implementation PrefsWindowController

+ (void)initialize
{
	// Register value transformers
	[NSValueTransformer setValueTransformer:[[ActionTypeHelpTransformer alloc] init]
					forName:@"ActionTypeHelpTransformer"];
	[NSValueTransformer setValueTransformer:[[DelayValueTransformer alloc] init]
					forName:@"DelayValueTransformer"];
	[NSValueTransformer setValueTransformer:[[LocalizeTransformer alloc] init]
					forName:@"LocalizeTransformer"];
	[NSValueTransformer setValueTransformer:[[WhenLocalizeTransformer alloc] init]
					forName:@"WhenLocalizeTransformer"];
	[NSValueTransformer setValueTransformer:[[RuleStatusResultTransformer alloc] init]
                    forName:@"RuleStatusResultTransformer"];
}

- (id)init
{
	if (!(self = [super init]))
		return nil;

	newActionWindowParameterViewCurrentControl = nil;

	[self setValue:@NO forKey:@"logBufferPaused"];
	logBufferTimer = nil;
    
    _logBufferUnchangedSince = [NSDate distantPast];

	return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)awakeFromNib
{
	// Evil!
	[NSValueTransformer setValueTransformer:[[ContextNameTransformer alloc] init:contextsDataSource]
					forName:@"ContextNameTransformer"];

	prefsGroups = @[
		[NSMutableDictionary dictionaryWithObjectsAndKeys:
			@"General", @"name",
			NSLocalizedString(@"General", "Preferences section"), @"display_name",
			@"GeneralPrefs", @"icon",
			generalPrefsView, @"view", nil],
		[NSMutableDictionary dictionaryWithObjectsAndKeys:
			@"Contexts", @"name",
			NSLocalizedString(@"Contexts", "Preferences section"), @"display_name",
			@"ContextsPrefs", @"icon",
            @YES, @"resizeableHeight",
			contextsPrefsView, @"view", nil],
		[NSMutableDictionary dictionaryWithObjectsAndKeys:
			@"EvidenceSources", @"name",
			NSLocalizedString(@"Evidence Sources", "Preferences section"), @"display_name",
			@"EvidenceSourcesPrefs", @"icon",
            @YES, @"resizeableHeight",
			evidenceSourcesPrefsView, @"view", nil],
		[NSMutableDictionary dictionaryWithObjectsAndKeys:
			@"Rules", @"name",
			NSLocalizedString(@"Rules", "Preferences section"), @"display_name",
			@"RulesPrefs", @"icon",
            @YES, @"resizeableWidth",
            @YES, @"resizeableHeight",
			rulesPrefsView, @"view", nil],
		[NSMutableDictionary dictionaryWithObjectsAndKeys:
			@"Actions", @"name",
			NSLocalizedString(@"Actions", "Preferences section"), @"display_name",
			@"ActionsPrefs", @"icon",
            @YES, @"resizeableWidth",
            @YES, @"resizeableHeight",
			actionsPrefsView, @"view", nil],
		[NSMutableDictionary dictionaryWithObjectsAndKeys:
			@"Advanced", @"name",
			NSLocalizedString(@"Advanced", "Preferences section"), @"display_name",
			@"AdvancedPrefs", @"icon",
            @YES, @"resizeableHeight",
			advancedPrefsView, @"view", nil],
		];

	// Store initial sizes of each prefs NSView as their "minimum" size
	for (NSMutableDictionary *group in prefsGroups) {
		NSView *view = group[@"view"];
		NSSize frameSize = [view frame].size;
		group[@"min_width"]  = @(frameSize.width);
		group[@"min_height"] = @(frameSize.height);
	}

	// Init. toolbar
	prefsToolbar = [[NSToolbar alloc] initWithIdentifier:@"prefsToolbar"];
	[prefsToolbar setDelegate:self];
	[prefsToolbar setAllowsUserCustomization:NO];
	[prefsToolbar setAutosavesConfiguration:NO];
    [prefsToolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];
	[prefsWindow setToolbar:prefsToolbar];

	currentPrefsGroup = nil;
	[self switchToView:@"General"];

    // display options for the menu bar


    [startAtLoginStatus setState:[self willStartAtLogin:[self appPath]] ? 1:0];
    [menuBarDisplayOptionsController addObject:
        [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @"Icon",@"option", 
            NSLocalizedString(@"Icon",@"Show only the icon"), @"description", 
            nil]];
    
    [menuBarDisplayOptionsController addObject:
        [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @"Context",@"option",
            NSLocalizedString(@"Context", @"Show only the current context"),@"description", 
            nil]];
    [menuBarDisplayOptionsController addObject:
        [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @"Both",@"option",
            NSLocalizedString(@"Both", @"Show both the icon and the current context"),@"description", 
            nil]];
 
    
 //   [menuBarDisplayOptionsController setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"menuBarOption"] forKey:@"selectedObject"];
   
	// Contexts
	[defaultContextButton setContextsDataSource:contextsDataSource];
	[editActionContextButton setContextsDataSource:contextsDataSource];

	// Make sure it gets loaded okay
	[defaultContextButton setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultContext"]
				forKey:@"selectedObject"];

	// Load up correct localisations
	[whenActionController addObject:
			[NSMutableDictionary dictionaryWithObjectsAndKeys:
				@"Arrival", @"option",
				NSLocalizedString(@"On arrival", @"When an action is triggered"), @"description",
				nil]];
	[whenActionController addObject:
			[NSMutableDictionary dictionaryWithObjectsAndKeys:
				@"Departure", @"option",
				NSLocalizedString(@"On departure", @"When an action is triggered"), @"description",
				nil]];
	[whenActionController addObject:
			[NSMutableDictionary dictionaryWithObjectsAndKeys:
				@"Both", @"option",
				NSLocalizedString(@"Both", @"When an action is triggered"), @"description",
				nil]];

	[logBufferView setFont:[NSFont fontWithName:@"Monaco" size:9]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onPrefsWindowClose:)
                                                 name:NSWindowWillCloseNotification
                                               object:prefsWindow];
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"userHasSeenMultipleActiveContextsNotification"]) {
        NSWindow *multipleActiveContextsNotification = self.multipleActiveContextsNotification;
        [multipleActiveContextsNotification makeKeyAndOrderFront:self];
    }
}

static NSString * const sizeParamPrefix = @"NSView Size Preferences/";

- (void)persistCurrentViewSize {
	NSSize minSize = [prefsWindow minSize], maxSize = [prefsWindow maxSize];
    if (currentPrefsGroup && ((minSize.width < maxSize.width) || (minSize.height < maxSize.height))) {
        NSString *sizeParamName = [sizeParamPrefix stringByAppendingString:currentPrefsGroup];

		NSSize size  = [prefsWindow frame].size;
        if ((size.width > minSize.width) || (size.height > minSize.height)) {
            size.height -= [self toolbarHeight] + [self titleBarHeight];
            NSData *persistedSize = [NSArchiver archivedDataWithRootObject:[NSValue valueWithSize:size]];
            [[NSUserDefaults standardUserDefaults] setObject:persistedSize forKey:sizeParamName];
        } else {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:sizeParamName];
        }
	}
}

- (NSValue *)getPersistedSizeOfViewNamed:(NSString *)name {
    NSString *sizeParamName = [sizeParamPrefix stringByAppendingString:name];
    NSData *persistedSize = [[NSUserDefaults standardUserDefaults] objectForKey:sizeParamName];
    if (!persistedSize) {
        return nil;
    }

    return (NSValue *) [NSUnarchiver unarchiveObjectWithData:persistedSize];
}

- (void)onPrefsWindowClose:(NSNotification *)notification {
    [self stopLogBufferTimer];
    [self persistCurrentViewSize];
}

- (IBAction)runPreferences:(id)sender {
	[NSApp activateIgnoringOtherApps:YES];
	[prefsWindow makeKeyAndOrderFront:self];
	if ([currentPrefsGroup isEqualToString:@"Advanced"]) {
        [self startLogBufferTimer];
	}
}

- (IBAction)runAbout:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
#if 0
	[NSApp orderFrontStandardAboutPanelWithOptions:@{ @"Version": @"" }];
#else
	AboutPanel *ctl = [[AboutPanel alloc] init];
	[ctl runPanel];
#endif
}

- (IBAction)runWebPage:(id)sender
{
	NSURL *url = [NSURL URLWithString:[[[NSBundle mainBundle] infoDictionary] valueForKey:@"CPWebPageURL"]];
	[[NSWorkspace sharedWorkspace] openURL:url];
}

- (IBAction)emailSupport:(id)sender 
{
    NSURL *url = [NSURL URLWithString:[[[NSBundle mainBundle] infoDictionary] valueForKey:@"CPSupportURL"]];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (IBAction)donateToControlPlane:(id)sender {
    NSURL *url = [NSURL URLWithString:[[[NSBundle mainBundle] infoDictionary] valueForKey:@"CPDonationURL"]];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (IBAction)menuBarDisplayOptionChanged:(id)sender {
}

- (IBAction)enableMultipleActiveContexts:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"AllowMultipleActiveContexts"];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"userHasSeenMultipleActiveContextsNotification"];
    
    NSWindow *multipleActiveContextsNotification = self.multipleActiveContextsNotification;
    [multipleActiveContextsNotification close];
}

- (IBAction)closeMultipleActiveContextsAlert:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"userHasSeenMultipleActiveContextsNotification"];
    
    NSWindow *multipleActiveContextsNotification = self.multipleActiveContextsNotification;
    [multipleActiveContextsNotification close];
}



#pragma mark Prefs group switching

- (NSMutableDictionary *)groupById:(NSString *)groupId
{
	for (NSMutableDictionary *group in prefsGroups) {
		if ([group[@"name"] isEqualToString:groupId]) {
			return group;
        }
    }
	return nil;
}

- (float)toolbarHeight
{
	NSRect contentRect;

	contentRect = [NSWindow contentRectForFrameRect:[prefsWindow frame] styleMask:[prefsWindow styleMask]];
	return (NSHeight(contentRect) - NSHeight([[prefsWindow contentView] frame]));
}

- (float)titleBarHeight
{
	return [prefsWindow frame].size.height - [[prefsWindow contentView] frame].size.height - [self toolbarHeight];
}

- (void)switchToViewFromToolbar:(NSToolbarItem *)item
{
	[self switchToView:[item itemIdentifier]];
}

- (void)switchToView:(NSString *)groupId
{
	NSDictionary *group = [self groupById:groupId];
	if (!group) {
		NSLog(@"Bad prefs group '%@' to switch to!", groupId);
		return;
	}

	if (currentPrefsView == group[@"view"]) {
		return;
    }

    [self persistCurrentViewSize];

	if ([groupId isEqualToString:@"Advanced"]) {
        [self startLogBufferTimer];
	} else {
        [self stopLogBufferTimer];
    }

	currentPrefsView = group[@"view"];

	NSSize minSize = NSMakeSize([group[@"min_width"] floatValue], [group[@"min_height"] floatValue]);
    NSSize size = minSize;

    NSValue *persistedSize = [self getPersistedSizeOfViewNamed:groupId];
    if (persistedSize) {
        size = [persistedSize sizeValue];
        if (size.width < minSize.width) {
            size.width = minSize.width;
        }
        if (size.height < minSize.height) {
            size.height = minSize.height;
        }
    }
    
	NSView *blankPrefsView = [[NSView alloc] init];
	[prefsWindow setContentView:blankPrefsView];
	[prefsWindow setTitle:[@"ControlPlane - " stringByAppendingString:group[@"display_name"]]];
    
	BOOL resizeableWidth  = [group[@"resizeableWidth"]  boolValue];
    BOOL resizeableHeight = [group[@"resizeableHeight"] boolValue];
    [self resizeWindowToSize:size withMinSize:minSize
               limitMaxWidth:!resizeableWidth
              limitMaxHeight:!resizeableHeight];
	[prefsWindow setShowsResizeIndicator:(resizeableWidth || resizeableHeight)];

	if ([prefsToolbar respondsToSelector:@selector(setSelectedItemIdentifier:)]) {
		[prefsToolbar setSelectedItemIdentifier:groupId];
    }

	[prefsWindow setContentView:currentPrefsView];
	[self setValue:groupId forKey:@"currentPrefsGroup"];
}

- (void)resizeWindowToSize:(NSSize)size
               withMinSize:(NSSize)minSize
             limitMaxWidth:(BOOL)limitMaxWidth
            limitMaxHeight:(BOOL)limitMaxHeight
{
	float tbHeight = [self toolbarHeight];
	float newWidth  = size.width;
	float newHeight = size.height;

	NSRect frame = [NSWindow contentRectForFrameRect:[prefsWindow frame]
					styleMask:[prefsWindow styleMask]];

	frame.origin.y += frame.size.height;
	frame.origin.y -= newHeight + tbHeight;
	frame.size.width = newWidth;
	frame.size.height = newHeight + tbHeight;

	frame = [NSWindow frameRectForContentRect:frame styleMask:[prefsWindow styleMask]];

	[prefsWindow setFrame:frame display:YES animate:YES];

	minSize.height += [self titleBarHeight];

    NSSize maxSize = NSMakeSize((limitMaxWidth  ? minSize.width  : FLT_MAX),
                                (limitMaxHeight ? minSize.height : FLT_MAX));

	[prefsWindow setMinSize:minSize];
	[prefsWindow setMaxSize:maxSize];
}

#pragma mark Toolbar delegates

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)groupId willBeInsertedIntoToolbar:(BOOL)flag
{
	NSEnumerator *en = [prefsGroups objectEnumerator];
	NSDictionary *group;

	while ((group = [en nextObject])) {
		if ([group[@"name"] isEqualToString:groupId])
			break;
	}
	if (!group) {
		NSLog(@"Oops! toolbar delegate is trying to use '%@' as an ID!", groupId);
		return nil;
	}

	NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:groupId];
	[item setLabel:[group objectForKey:@"display_name"]];
	[item setPaletteLabel:[group objectForKey:@"display_name"]];
	[item setImage:[NSImage imageNamed:[group objectForKey:@"icon"]]];
	[item setTarget:self];
	[item setAction:@selector(switchToViewFromToolbar:)];

	return item;
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:[prefsGroups count]];

	for (NSDictionary *group in prefsGroups) {
		[array addObject:group[@"name"]];
    }

	return array;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	return [self toolbarAllowedItemIdentifiers:toolbar];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
	return [self toolbarAllowedItemIdentifiers:toolbar];
}

#pragma mark Rule creation/editing

- (void)addRule:(id)sender
{
	EvidenceSource *src;
	NSString *type;
	// Represented object in this action is either:
	//	(a) an EvidenceSource object, or
	//	(b) an 2-tuple: [EvidenceSource object, rule_type]
	if ([[sender representedObject] isKindOfClass:[NSArray class]]) {
		// specific type
		NSArray *arr = [sender representedObject];
		src = arr[0];
		type = arr[1];
	} else {
		src = [sender representedObject];
		type = [src typesOfRulesMatched][0];
	}
	
	[src setContextMenu:[contextsDataSource hierarchicalMenu]];

	[NSApp activateIgnoringOtherApps:YES];
	NSDictionary *proto = [NSDictionary dictionaryWithObject:type forKey:@"type"];
	[src runPanelAsSheetOfWindow:prefsWindow
		       withParameter:proto
		      callbackObject:self
			    selector:@selector(doAddRule:)];
}

// Private: called by -[EvidenceSource runPanelAsSheetOfWindow:...]
- (void)doAddRule:(NSDictionary *)dict
{
	[rulesController addObject:dict];
}

- (IBAction)editRule:(id)sender
{
	// Find relevant evidence source
	id sel = [[rulesController selectedObjects] lastObject];
	if (!sel)
		return;

	NSString *type = [sel valueForKey:@"type"];
	NSEnumerator *en = [evidenceSources sourceEnumerator];
	EvidenceSource *src;
	while ((src = [en nextObject]) && ![src matchesRulesOfType:type]) {
		// TODO: use some more intelligent selection method?
		// This just gets the first evidence source that matches
		// this rule type, so it will probably break if we have
		// multiple evidence sources that match/suggest the same
		// rule types (e.g. *MAC* rules!!!)
	}
	if (!src) {
		return;
    }

    NSString *key = [NSString stringWithFormat:@"Enable%@EvidenceSource", [src name]];
    if (![src isRunning] || ![[NSUserDefaults standardUserDefaults] boolForKey:key]) {
        [RuleType alertWithMessage:NSLocalizedString(@"Evidence source for this rule is disabled",
                                                     @"Shown when the user attempt to edit rule with disabled ES.")
                   informativeText:NSLocalizedString(@"You need to enable the corresponding evidence source"
                                                     " to be able to edit the rule",
                                                     @"Shown when the user attempt to edit rule with disabled ES.")];
        return;
    }

	[src setContextMenu:[contextsDataSource hierarchicalMenu]];

	[NSApp activateIgnoringOtherApps:YES];
	[src runPanelAsSheetOfWindow:prefsWindow
		       withParameter:sel
		      callbackObject:self
			    selector:@selector(doEditRule:)];
}

// Private: called by -[EvidenceSource runPanelAsSheetOfWindow:...]
- (void)doEditRule:(NSDictionary *)dict
{
	NSUInteger index = [rulesController selectionIndex];
	[rulesController removeObjectAtArrangedObjectIndex:index];
	[rulesController insertObject:dict atArrangedObjectIndex:index];
	[rulesController setSelectionIndex:index];
}

#pragma mark Action creation

- (void)addAction:(id)sender
{
	Class klass = [sender representedObject];
	[self setValue:[Action typeForClass:klass] forKey:@"newActionType"];
	[self setValue:NSLocalizedString([Action typeForClass:klass], @"Action type")
		forKey:@"newActionTypeString"];

	[self setValue:[klass creationHelpText] forKey:@"newActionWindowHelpText"];
	[self setValue:@"Arrival" forKey:@"newActionWindowWhen"];

	[newActionWindow setTitle:[NSString stringWithFormat:
		NSLocalizedString(@"New %@ Action", @"Window title"), newActionTypeString]];

	[newActionContext setMenu:[contextsDataSource hierarchicalMenu]];

	if ([klass conformsToProtocol:@protocol(ActionWithLimitedOptions)]) {
		NSArrayController *loC = newActionLimitedOptionsController;
		[loC removeObjects:[loC arrangedObjects]];
        NSArray *returnedOptions = [klass limitedOptions];
        if (!returnedOptions) {
            return;
        }
		[loC addObjects:[klass limitedOptions]];
		[loC selectNext:self];

		NSRect frame = [newActionWindowParameterView bounds];
		frame.size.height = 26;		// HACK!
		NSPopUpButton *pub = [[NSPopUpButton alloc] initWithFrame:frame pullsDown:NO];
		// Bindings:
		[pub bind:@"content" toObject:loC withKeyPath:@"arrangedObjects" options:nil];
		[pub bind:@"contentValues" toObject:loC withKeyPath:@"arrangedObjects.description" options:nil];
		[pub bind:@"selectedIndex" toObject:loC withKeyPath:@"selectionIndex" options:nil];

		if (newActionWindowParameterViewCurrentControl)
			[newActionWindowParameterViewCurrentControl removeFromSuperview];
		[newActionWindowParameterView addSubview:pub];
		newActionWindowParameterViewCurrentControl = pub;

		[NSApp activateIgnoringOtherApps:YES];
		[newActionWindow makeKeyAndOrderFront:self];
		return;
	} else if ([klass conformsToProtocol:@protocol(ActionWithFileParameter)]) {
		NSOpenPanel *panel = [NSOpenPanel openPanel];
		[panel setAllowsMultipleSelection:NO];
		[panel setCanChooseDirectories:NO];
		if ([panel runModal] != NSOKButton)
			return;
		NSString *filename = [[panel URL] path];
		Action *action = [[klass alloc] initWithFile:filename];

		NSMutableDictionary *actionDictionary = [action dictionary];
		[actionsController addObject:actionDictionary];
		[actionsController setSelectedObjects:[NSArray arrayWithObject:actionDictionary]];
		return;
	} else if ([klass conformsToProtocol:@protocol(ActionWithString)]) {
		NSRect frame = [newActionWindowParameterView bounds];
		frame.size.height = 22;		// HACK!
		NSTextField *tf = [[NSTextField alloc] initWithFrame:frame];
		[tf setStringValue:@""];	// TODO: sensible initialisation?

		if (newActionWindowParameterViewCurrentControl)
			[newActionWindowParameterViewCurrentControl removeFromSuperview];
		[newActionWindowParameterView addSubview:tf];
		newActionWindowParameterViewCurrentControl = tf;

		[NSApp activateIgnoringOtherApps:YES];
		[newActionWindow makeKeyAndOrderFront:self];
		return;
	}

	// Worst-case fallback: just make a new action, and select it:
	Action *action = [[[sender representedObject] alloc] init];
	NSMutableDictionary *actionDictionary = [action dictionary];

	[actionsController addObject:actionDictionary];
	[actionsController setSelectedObjects:[NSArray arrayWithObject:actionDictionary]];
}

- (IBAction)doAddAction:(id)sender
{
	Class klass = [Action classForType:newActionType];
	Action *tmp_action = [[klass alloc] init];
	NSMutableDictionary *dict = [tmp_action dictionary];

	// Pull parameter out of the right type of UI control
	NSString *param, *desc = nil;
	if ([klass conformsToProtocol:@protocol(ActionWithLimitedOptions)]) {
		NSDictionary *sel = [[newActionLimitedOptionsController selectedObjects] lastObject];
        DSLog(@"doAddAction sees %@",sel);
		param = [sel valueForKey:@"option"];
		desc = [sel valueForKey:@"description"];
	} else if ([klass conformsToProtocol:@protocol(ActionWithString)]) {
		NSTextField *tf = (NSTextField *) newActionWindowParameterViewCurrentControl;
		param = [tf stringValue];
	} else {
		NSLog(@"PANIC! Don't know how to get parameter!!!");
		return;
	}

	// Finish creating dictionary
	[dict setValue:param forKey:@"parameter"];
	[dict setValue:[[newActionContext selectedItem] representedObject] forKey:@"context"];
	[dict setValue:newActionWindowWhen forKey:@"when"];
	if (desc)
		[dict setValue:desc forKey:@"description"];

	// Stick it in action collection, and select it
	[actionsController addObject:dict];
	[actionsController setSelectedObjects:[NSArray arrayWithObject:dict]];

	[newActionWindow performClose:self];
}

#pragma mark Login Item Routines

- (NSURL *)appPath
{
    return [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
}

- (void)startAtLogin
{
    LSSharedFileListRef loginItemList = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItemList != NULL) {
#ifdef DEBUG_MODE
        DSLog(@"Adding ControlPlane to startup items");
#endif
        
        LSSharedFileListItemRef newItem = LSSharedFileListInsertItemURL(loginItemList,
                                                                        kLSSharedFileListItemBeforeFirst,
                                                                        NULL, NULL,
                                                                        (__bridge CFURLRef)[self appPath],
                                                                        NULL, NULL);
        if (newItem != NULL) {
            CFRelease(newItem);
        }
        CFRelease(loginItemList);
    }
}

- (void) disableStartAtLogin
{
    NSURL *appPath = [self appPath];
    
    // Creates shared file list reference to be used for changing list and reading its various properties.
    LSSharedFileListRef loginItemList = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItemList == NULL) {
        return;
    }
    
    // take a snapshot of the list creating an array out of it
    UInt32 seedValue = 0;
    CFArrayRef currentLoginItems = LSSharedFileListCopySnapshot(loginItemList, &seedValue);
    
    if (currentLoginItems != NULL) {
        const UInt32 resolveFlags = (kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes);
        
        // walk the array looking for an entry that belongs to us
        for (id currentLoginItem in (__bridge NSArray *)currentLoginItems) {
            LSSharedFileListItemRef itemToCheck = (__bridge LSSharedFileListItemRef)currentLoginItem;
            
            BOOL startupItemFound = NO;
            CFURLRef pathOfCurrentItem = NULL;
            if (LSSharedFileListItemResolve(itemToCheck, resolveFlags, &pathOfCurrentItem, NULL) == noErr) {
                startupItemFound = ((pathOfCurrentItem != NULL)
                                    && CFEqual(pathOfCurrentItem, (__bridge CFURLRef)appPath));
            }
            
            if (pathOfCurrentItem != NULL) {
                CFRelease(pathOfCurrentItem);
            }
            
            if (startupItemFound) {
#ifdef DEBUG_MODE
                DSLog(@"Removing ControlPlan from startup items");
#endif
                
                LSSharedFileListItemRemove(loginItemList, itemToCheck);
                break;
            }
        }
        
        CFRelease(currentLoginItems);
    }
    
    CFRelease(loginItemList);
}

- (BOOL)willStartAtLogin:(NSURL *)appPath
{
    if (appPath == NULL) {
        return NO;
    }
    
    // Creates shared file list reference to be used for changing list and reading its various properties.
    LSSharedFileListRef loginItemList = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItemList == NULL) {
        return NO;
    }
    
    // check to see if ControlPlane is already listed in Start Up Items
    BOOL isControlPlaneListed = NO;
    
    // take a snapshot of the list creating an array out of it
    UInt32 seedValue = 0;
    CFArrayRef currentLoginItems = LSSharedFileListCopySnapshot(loginItemList, &seedValue);
    
    if (currentLoginItems != NULL) {
        const UInt32 resolveFlags = (kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes);
        
        // walk the array looking for an entry that belongs to us
        for (id currentLoginItem in (__bridge NSArray *)currentLoginItems) {
            LSSharedFileListItemRef itemToCheck = (__bridge LSSharedFileListItemRef)currentLoginItem;
            
            CFURLRef pathOfCurrentItem = NULL;
            if (LSSharedFileListItemResolve(itemToCheck, resolveFlags, &pathOfCurrentItem, NULL) == noErr) {
                isControlPlaneListed = ((pathOfCurrentItem != NULL)
                                        && CFEqual(pathOfCurrentItem, (__bridge CFURLRef)appPath));
            }
            if (pathOfCurrentItem != NULL) {
                CFRelease(pathOfCurrentItem);
            }
            
            if (isControlPlaneListed) {
                break;
            }
        }
        
        CFRelease(currentLoginItems);
    }
    
    CFRelease(loginItemList);
	
    return isControlPlaneListed;
}

- (IBAction)toggleStartAtLoginAction:(id)sender
{
    if ([self willStartAtLogin:[self appPath]]) {
        [self disableStartAtLogin];
    }
    else {
        [self startAtLogin];
    }
    [startAtLoginStatus setState:[self willStartAtLogin:[self appPath]] ? 1:0];
}


#pragma mark Miscellaneous

- (void)startLogBufferTimer {
    if (logBufferTimer == nil) {
        logBufferTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)0.5
                                                          target:self
                                                        selector:@selector(updateLogBuffer:)
                                                        userInfo:nil
                                                         repeats:YES];
        
        if ([logBufferTimer respondsToSelector:@selector(setTolerance:)])
            [logBufferTimer setTolerance:(NSTimeInterval) 1];
            
        [logBufferTimer fire];
    }
}

- (void)stopLogBufferTimer {
    if (logBufferTimer != nil) {
        if (logBufferTimer.isValid) {
            [logBufferTimer invalidate];
        }
        logBufferTimer = nil;
    }
}

- (void)updateLogBuffer:(NSTimer *)timer {
	if (![logBufferPaused boolValue]) {
        DSLogger *logger = [DSLogger sharedLogger];
        NSDate *lastLogUpdateTime = logger.lastUpdatedAt;
        if ([self.logBufferUnchangedSince isLessThan:lastLogUpdateTime]) {
            self.logBufferUnchangedSince = lastLogUpdateTime;
            NSString *buf = [logger buffer];
            [logBufferView setString:buf];
            [logBufferView scrollRangeToVisible:NSMakeRange([buf length] - 2, 1)];
        }
	}
}

@end
