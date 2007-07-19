#import "Action.h"
#import "EvidenceSource.h"
#import "PrefsWindowController.h"


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
	int res = 0;

	if (!value || [value isEqualToString:NSLocalizedString(@"None", @"Delay value to display for zero seconds")])
		res = 0;
	else
		res = [value intValue];

	return [NSNumber numberWithInt:res];
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
	NSString *eng_str = [NSString stringWithFormat:@"On %@", [(NSString *) theValue lowercaseString]];
	
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
	return [[contextsDataSource contextByUUID:(NSString *) theValue] name];
}

@end

@implementation PrefsWindowController

+ (void)initialize
{
	// Register value transformers
	[NSValueTransformer setValueTransformer:[[[ActionTypeHelpTransformer alloc] init] autorelease]
					forName:@"ActionTypeHelpTransformer"];
	[NSValueTransformer setValueTransformer:[[[DelayValueTransformer alloc] init] autorelease]
					forName:@"DelayValueTransformer"];
	[NSValueTransformer setValueTransformer:[[[LocalizeTransformer alloc] init] autorelease]
					forName:@"LocalizeTransformer"];
	[NSValueTransformer setValueTransformer:[[[WhenLocalizeTransformer alloc] init] autorelease]
					forName:@"WhenLocalizeTransformer"];
}

- (id)init
{
	if (!(self = [super init]))
		return nil;

	blankPrefsView = [[NSView alloc] init];

	newActionWindowParameterViewCurrentControl = nil;

	return self;
}

- (void)dealloc
{
	[blankPrefsView release];
	[super dealloc];
}

- (void)awakeFromNib
{
	// Evil!
	[NSValueTransformer setValueTransformer:[[[ContextNameTransformer alloc] init:contextsDataSource] autorelease]
					forName:@"ContextNameTransformer"];

	prefsGroups = [[NSArray arrayWithObjects:
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"General", @"name",
			NSLocalizedString(@"General", "Preferences section"), @"display_name",
			@"GeneralPrefs", @"icon",
			generalPrefsView, @"view", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"Contexts", @"name",
			NSLocalizedString(@"Contexts", "Preferences section"), @"display_name",
			@"ContextsPrefs", @"icon",
			contextsPrefsView, @"view", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"EvidenceSources", @"name",
			NSLocalizedString(@"Evidence Sources", "Preferences section"), @"display_name",
			@"EvidenceSourcesPrefs", @"icon",
			evidenceSourcesPrefsView, @"view", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"Rules", @"name",
			NSLocalizedString(@"Rules", "Preferences section"), @"display_name",
			@"RulesPrefs", @"icon",
			rulesPrefsView, @"view", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"Actions", @"name",
			NSLocalizedString(@"Actions", "Preferences section"), @"display_name",
			@"ActionsPrefs", @"icon",
			actionsPrefsView, @"view", nil],
		[NSDictionary dictionaryWithObjectsAndKeys:
			@"Advanced", @"name",
			NSLocalizedString(@"Advanced", "Preferences section"), @"display_name",
			@"AdvancedPrefs", @"icon",
			advancedPrefsView, @"view", nil],
		nil] retain];

	// Init. toolbar
	prefsToolbar = [[NSToolbar alloc] initWithIdentifier:@"prefsToolbar"];
	[prefsToolbar setDelegate:self];
	[prefsToolbar setAllowsUserCustomization:NO];
	[prefsToolbar setAutosavesConfiguration:NO];
        [prefsToolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];
	[prefsWindow setToolbar:prefsToolbar];

	[self switchToView:@"General"];

	// Contexts
	[defaultContextButton setContextsDataSource:contextsDataSource];
	[editRuleContextButton setContextsDataSource:contextsDataSource];
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
}

- (IBAction)runPreferences:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	[prefsWindow makeKeyAndOrderFront:self];
}

- (IBAction)runAbout:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	[NSApp orderFrontStandardAboutPanelWithOptions:
		[NSDictionary dictionaryWithObject:@"" forKey:@"Version"]];
}

- (IBAction)runWebPage:(id)sender
{
	NSURL *url = [NSURL URLWithString:[[[NSBundle mainBundle] infoDictionary] valueForKey:@"MPWebPageURL"]];
	[[NSWorkspace sharedWorkspace] openURL:url];
}

#pragma mark Prefs group switching

- (void)switchToViewFromToolbar:(NSToolbarItem *)item
{
	[self switchToView:[item itemIdentifier]];
}

- (void)switchToView:(NSString *)groupId
{
	NSEnumerator *en = [prefsGroups objectEnumerator];
	NSDictionary *group;

	while ((group = [en nextObject])) {
		if ([[group objectForKey:@"name"] isEqualToString:groupId])
			break;
	}
	if (!group) {
		NSLog(@"Bad prefs group '%@' to switch to!\n", groupId);
		return;
	}

	if (currentPrefsView == [group objectForKey:@"view"])
		return;
	currentPrefsView = [group objectForKey:@"view"];

	[drawer close];

	[prefsWindow setContentView:blankPrefsView];
	[prefsWindow setTitle:[NSString stringWithFormat:@"MarcoPolo - %@", [group objectForKey:@"display_name"]]];
	[self resizeWindowToSize:[currentPrefsView frame].size];

	if ([prefsToolbar respondsToSelector:@selector(setSelectedItemIdentifier:)])
		[prefsToolbar setSelectedItemIdentifier:groupId];
	[prefsWindow setContentView:currentPrefsView];
}

- (void)resizeWindowToSize:(NSSize)size
{
	NSRect frame, contentRect;
	float tbHeight, newHeight, newWidth;

	contentRect = [NSWindow contentRectForFrameRect:[prefsWindow frame]
					      styleMask:[prefsWindow styleMask]];
	tbHeight = (NSHeight(contentRect) - NSHeight([[prefsWindow contentView] frame]));

	newHeight = size.height;
	newWidth = size.width;

	frame = [NSWindow contentRectForFrameRect:[prefsWindow frame]
					styleMask:[prefsWindow styleMask]];

	frame.origin.y += frame.size.height;
	frame.origin.y -= newHeight + tbHeight;
	frame.size.height = newHeight + tbHeight;
	frame.size.width = newWidth;

	frame = [NSWindow frameRectForContentRect:frame
					styleMask:[prefsWindow styleMask]];

	[prefsWindow setFrame:frame display:YES animate:YES];
}

#pragma mark Toolbar delegates

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)groupId willBeInsertedIntoToolbar:(BOOL)flag
{
	NSEnumerator *en = [prefsGroups objectEnumerator];
	NSDictionary *group;

	while ((group = [en nextObject])) {
		if ([[group objectForKey:@"name"] isEqualToString:groupId])
			break;
	}
	if (!group) {
		NSLog(@"Oops! toolbar delegate is trying to use '%@' as an ID!\n", groupId);
		return nil;
	}

	NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:groupId];
	[item setLabel:[group objectForKey:@"display_name"]];
	[item setPaletteLabel:[group objectForKey:@"display_name"]];
	[item setImage:[NSImage imageNamed:[group objectForKey:@"icon"]]];
	[item setTarget:self];
	[item setAction:@selector(switchToViewFromToolbar:)];

	return [item autorelease];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:[prefsGroups count]];

	NSEnumerator *en = [prefsGroups objectEnumerator];
	NSDictionary *group;

	while ((group = [en nextObject]))
		[array addObject:[group objectForKey:@"name"]];

	return array;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
	return [self toolbarAllowedItemIdentifiers:toolbar];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	return [self toolbarAllowedItemIdentifiers:toolbar];
}

#pragma mark Rule creation/editing

- (void)addRule:(id)sender
{
	EvidenceSource *src;
	NSString *name, *type;
	// Represented object in this action is either:
	//	(a) an EvidenceSource object, or 
	//	(b) an 2-tuple: [EvidenceSource object, rule_type]
	if ([[sender representedObject] isKindOfClass:[NSArray class]]) {
		// specific type
		NSArray *arr = [sender representedObject];
		src = [arr objectAtIndex:0];
		type = [arr objectAtIndex:1];
	} else {
		src = [sender representedObject];
		type = [[src typesOfRulesMatched] objectAtIndex:0];
	}
	name = [src name];


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
	while ((src = [en nextObject])) {
		if (![src matchesRulesOfType:type])
			continue;
		// TODO: use some more intelligent selection method?
		// This just gets the first evidence source that matches
		// this rule type, so it will probably break if we have
		// multiple evidence sources that match/suggest the same
		// rule types (e.g. *MAC* rules!!!)
		break;
	}
	if (!src)
		return;

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
	unsigned int index = [rulesController selectionIndex];
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
		[loC addObjects:[klass limitedOptions]];
		[loC selectNext:self];

		NSRect frame = [newActionWindowParameterView bounds];
		frame.size.height = 26;		// HACK!
		NSPopUpButton *pub = [[[NSPopUpButton alloc] initWithFrame:frame pullsDown:NO] autorelease];
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
		NSString *filename = [panel filename];
		Action *action = [[[klass alloc] initWithFile:filename] autorelease];

		NSMutableDictionary *actionDictionary = [action dictionary];
		[actionsController addObject:actionDictionary];
		[actionsController setSelectedObjects:[NSArray arrayWithObject:actionDictionary]];
		return;
	} else if ([klass conformsToProtocol:@protocol(ActionWithString)]) {
		NSRect frame = [newActionWindowParameterView bounds];
		frame.size.height = 22;		// HACK!
		NSTextField *tf = [[[NSTextField alloc] initWithFrame:frame] autorelease];
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
	Action *action = [[[[sender representedObject] alloc] init] autorelease];
	NSMutableDictionary *actionDictionary = [action dictionary];

	[actionsController addObject:actionDictionary];
	[actionsController setSelectedObjects:[NSArray arrayWithObject:actionDictionary]];
}

- (IBAction)doAddAction:(id)sender
{
	Class klass = [Action classForType:newActionType];
	Action *tmp_action = [[klass alloc] init];
	NSMutableDictionary *dict = [tmp_action dictionary];
	[tmp_action release];

	// Pull parameter out of the right type of UI control
	NSString *param;
	if ([klass conformsToProtocol:@protocol(ActionWithLimitedOptions)]) {
		NSDictionary *sel = [[newActionLimitedOptionsController selectedObjects] lastObject];
		param = [sel valueForKey:@"option"];
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

	// Stick it in action collection, and select it
	[actionsController addObject:dict];
	[actionsController setSelectedObjects:[NSArray arrayWithObject:dict]];

	[newActionWindow performClose:self];
}

@end
