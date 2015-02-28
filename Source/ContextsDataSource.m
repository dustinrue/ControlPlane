//
//  ContextsDataSource.m
//  ControlPlane
//
//  Created by David Symonds on 3/07/07.
//
//  Modified by VladimirTechMan (Vladimir Beloborodov) on 23 May 2014. The code is reworked for ARC.
//
//  IMPORTANT: This code is intended to be compiled for the ARC mode
//

#import "ContextsDataSource.h"
#import "CPController.h"
#import "DSLogger.h"
#import "SliderWithValue.h"
#import "SharedNumberFormatter.h"

@interface Context ()

// Transient
@property (nonatomic,strong,readwrite) NSNumber *depth;

@end

@implementation Context

@synthesize iconColor = _iconColor;

- (id)init
{
	self = [super init];
    if (self == nil) {
		return nil;
    }
    
	CFUUIDRef ref = CFUUIDCreate(NULL);
	_uuid = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, ref);
	CFRelease(ref);
    
	_parentUUID = [[NSString alloc] init];
	_name = [_uuid copy];
    
	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
    self = [super init];
	if (self == nil) {
		return nil;
    }

	_uuid = [dict[@"uuid"] copy];
	_parentUUID = [dict[@"parent"] copy];
	_name = [dict[@"name"] copy];

    NSData *colorData = dict[@"iconColor"];
    if (colorData != nil) {
        _iconColor = [(NSColor *) [NSUnarchiver unarchiveObjectWithData:colorData] copy];
    }

	return self;
}

- (NSColor *)iconColor
{
    return (_iconColor != nil) ? (_iconColor) : [NSColor blackColor];
}

- (void)setIconColor:(NSColor *)iconColor
{
    _iconColor = [iconColor copy];
}

- (BOOL)isRoot
{
	return ([self.parentUUID length] == 0);
}

- (NSDictionary *)dictionary
{
    if ((_iconColor == nil) || ([_iconColor alphaComponent] == 0.0)) { // clear is the default value
        return @{ @"uuid": self.uuid, @"parent": self.parentUUID, @"name": self.name };
    }

    NSData *colorData = [NSArchiver archivedDataWithRootObject:(_iconColor)];
    return @{ @"uuid": self.uuid, @"parent": self.parentUUID, @"name": self.name, @"iconColor": colorData };
}

- (NSComparisonResult)compare:(Context *)ctxt
{
	return [self.name compare:[ctxt name]];
}

// Used by -[ContextsDataSource pathFromRootTo:]
- (NSString *)description
{
	return self.name;
}

@end


#pragma mark -
#pragma mark -

@implementation ContextsDataSource {
	NSMutableDictionary *contexts;
    // 10.7 can't use weak references to most of the items below
    // so we use __unsafe_unretained instead
    __unsafe_unretained IBOutlet NSButton *generalPreferencesEnableSwitching;
    __unsafe_unretained IBOutlet NSButton *generalPreferencesStartAtLogin;
    __unsafe_unretained IBOutlet NSButton *generalPreferencesUseNotifications;
    __unsafe_unretained IBOutlet NSButton *generalPreferencesCheckForUpdates;
    __unsafe_unretained IBOutlet NSButton *generalPreferencesHideFromStatusBar;
    __unsafe_unretained IBOutlet NSPopUpButton *generalPreferencesShowInStatusBar;
    __unsafe_unretained IBOutlet NSButton *generalPreferencesSwitchSmoothing;
    __unsafe_unretained IBOutlet NSButton *generalPreferencesRestorePreviousContext;
    __unsafe_unretained IBOutlet NSButton *generalPreferencesUseDefaultContextTextField;
    __unsafe_unretained IBOutlet NSTextField *generalPreferencesCRtSTextField;
    __unsafe_unretained IBOutlet SliderWithValue *generalPreferencesConfidenceSlider;
    
	// shouldn't _really_ be here
	__unsafe_unretained IBOutlet NSOutlineView *outlineView;
	Context *selection;
    
	__unsafe_unretained IBOutlet NSWindow *prefsWindow;
    
	__unsafe_unretained IBOutlet NSPanel *newContextSheet;
	__unsafe_unretained IBOutlet NSTextField *newContextSheetName;
    __unsafe_unretained IBOutlet NSColorWell *newContextSheetColor;
    __unsafe_unretained IBOutlet NSButton *newContextSheetColorPreviewEnabled;
}

+ (void)initialize
{
	[self exposeBinding:@"selection"];	// outlineView selection binding proxy
}

- (id)init
{
	self = [super init];
    if (self == nil) {
		return nil;
    }

	contexts = [[NSMutableDictionary alloc] init];
	[self loadContexts];

	// Make sure we get to save out the contexts
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(saveContexts:)
                                                 name:NSApplicationWillTerminateNotification
                                               object:nil];

	return self;
}

static NSString *MovedRowsType = @"MOVED_ROWS_TYPE";

- (void)awakeFromNib
{
	// register for drag and drop
    NSOutlineView *strongOutlineView = outlineView;
	[strongOutlineView registerForDraggedTypes:[NSArray arrayWithObject:MovedRowsType]];
    
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(triggerOutlineViewReloadData:)
                                                 name:@"ContextsChangedNotification"
                                               object:self];
    /*
     IBOutlet NSButton *generalPreferencesEnableSwitching;
     IBOutlet NSButton *generalPreferencesStartAtLogin;
     IBOutlet NSButton *generalPreferencesUseNotifications;
     IBOutlet NSButton *generalPreferencesCheckForUpdates;
     IBOutlet NSButton *generalPreferencesHideFromStatusBar;
     IBOutlet NSPopUpButton *generalPreferencesShowInStatusBar;
     IBOutlet NSButton *generalPreferencesSwitchSmoothing;
     IBOutlet NSButton *generalPreferencesRestorePreviousContext;
     IBOutlet NSButton *generalPreferencesUseDefaultContextTextField;
     IBOutlet NSTextField *generalPreferencesCRtSTextField;
     IBOutlet SliderWithValue *generalPreferencesConfidenceSlider;
     */
    NSButton *strongGeneralPreferencesEnableSwitching = generalPreferencesEnableSwitching;
    [strongGeneralPreferencesEnableSwitching setToolTip:NSLocalizedString(@"Check this option if you want ControlPlane to automatically switch to the context it is most confident about as configured by the 'Confidence required to switch' slider.", @"")];
    
    NSButton *strongGeneralPreferencesStartAtLogin = generalPreferencesStartAtLogin;
    [strongGeneralPreferencesStartAtLogin setToolTip:NSLocalizedString(@"Check this option if you want ControlPlane to start when you login.", @"")];
    
    NSButton *strongGeneralPreferencesUseNotifications = generalPreferencesUseNotifications;
    [strongGeneralPreferencesUseNotifications setToolTip:NSLocalizedString(@"Check this option if you want to ControlPlane to issue notifications.  If checked, Growl will be used on system's older than 10.8 and Notification Center will be used on systems 10.8 or newer.", @"")];
    
    NSButton *strongGeneralPreferencesCheckForUpdates = generalPreferencesCheckForUpdates;
    [strongGeneralPreferencesCheckForUpdates setToolTip:NSLocalizedString(@"If checked, ControlPlane will check for updates when it starts.", @"")];
    
    NSButton *strongGeneralPreferencesHideFromStatusBar = generalPreferencesHideFromStatusBar;
    [strongGeneralPreferencesHideFromStatusBar setToolTip:NSLocalizedString(@"If enabled ControlPlane's menu bar icon will be hidden after a period of time.  To make the icon visible again relaunch ControlPlane.", @"")];
    
    NSPopUpButton *strongGeneralPreferencesShowInStatusBar = generalPreferencesShowInStatusBar;
    [strongGeneralPreferencesShowInStatusBar setToolTip:NSLocalizedString(@"Select the information you want shown in the menu bar", @"")];
    
    NSButton *strongGeneralPreferencesSwitchSmoothing = generalPreferencesSwitchSmoothing;
    [strongGeneralPreferencesSwitchSmoothing setToolTip:NSLocalizedString(@"If enabled ControlPlane will allow two rule check cycles to be performed before switching to the most confident context.  Use this option if ControlPlane switches contexts too often or too quickly.", @"")];
    
    NSButton *strongGeneralPreferencesRestorePreviousContext = generalPreferencesRestorePreviousContext;
    [strongGeneralPreferencesRestorePreviousContext setToolTip:NSLocalizedString(@"Enable this option if you want ControlPlane to move to context it was at before it was last quit.  This only affects ControlPlane's behavior when the app is started and it wasn't previously running.  To perform actions on sleep or wake use the Sleep/Wake Evidence Source.", @"")];
    
    NSButton *strongGeneralPreferencesUseDefaultContextTextField = generalPreferencesUseDefaultContextTextField;
    [strongGeneralPreferencesUseDefaultContextTextField setToolTip:NSLocalizedString(@"Enable this option to cause ControlPlane to move to the selected context when it is unable to determine a better context.", @"")];
    
    NSString *confidenceToolTip = NSLocalizedString(@"Based on the rules you configure, ControlPlane will calculate how confident it is that a given set of rules match the context they are configured for.  This slider defines how confident ControlPlane needs to be to switch to that context.",@"");
    
    SliderWithValue *strongGeneralPreferencesConfidenceSlider = generalPreferencesConfidenceSlider;
    [strongGeneralPreferencesConfidenceSlider setToolTip:confidenceToolTip];
    
    NSTextField *strongGeneralPreferencesCRtSTextField = generalPreferencesCRtSTextField;
    [strongGeneralPreferencesCRtSTextField setToolTip:confidenceToolTip];
}

// Private
- (void)postContextsChangedNotification
{
	[self saveContexts:self];		// make sure they're saved
    
    @try {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ContextsChangedNotification" object:self];    
    }
    @catch (NSException * exception) {
        DSLog(@"unable to post ContextsChangedNotification because: %@", [exception reason]);
    }
	
}

#pragma mark -

// Private: assumes any depths already set in other contexts are correct, except when it's negative
- (void)recomputeDepthOf:(Context *)context {
	if ([context.depth intValue] >= 0)
		return;

	Context *parent = [contexts objectForKey:[context parentUUID]];
	if (!parent) {
		context.depth = @0;
    } else {
		[self recomputeDepthOf:parent];
        context.depth = @([parent.depth intValue] + 1);
	}
}

// Private
- (void)recomputeTransientData {
	// Recalculate depths
    [contexts enumerateKeysAndObjectsUsingBlock:^(id key, Context *ctxt, BOOL *stop) {
        ctxt.depth = ([ctxt isRoot]) ? (@0) : (@-1);
    }];

    [contexts enumerateKeysAndObjectsUsingBlock:^(id key, Context *ctxt, BOOL *stop) {
		if (![ctxt isRoot]) {
			[self recomputeDepthOf:ctxt];
        }
    }];

	// XXX: any other data to recompute?
}

#pragma mark -

- (void)loadContexts
{
	[contexts removeAllObjects];

	for (NSDictionary *dict in [[NSUserDefaults standardUserDefaults] objectForKey:@"Contexts"]) {
		Context *ctxt = [[Context alloc] initWithDictionary:dict];
		[contexts setValue:ctxt forKey:[ctxt uuid]];
    }

	// Check consistency of parent UUIDs; drop the parent UUID if it is invalid
    [contexts enumerateKeysAndObjectsUsingBlock:^(id key, Context *ctxt, BOOL *stop) {
		if (![ctxt isRoot] && ![contexts objectForKey:[ctxt parentUUID]]) {
			NSLog(@"%s correcting broken parent UUID for context '%@'", __PRETTY_FUNCTION__, [ctxt name]);
			[ctxt setParentUUID:@""];
		}
    }];

	[self recomputeTransientData];
	[self postContextsChangedNotification];
}

- (void)saveContexts:(id)arg {
	// Write out
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:[contexts count]];
    [contexts enumerateKeysAndObjectsUsingBlock:^(id key, Context *ctxt, BOOL *stop) {
		[array addObject:[ctxt dictionary]];
    }];

	[[NSUserDefaults standardUserDefaults] setObject:array forKey:@"Contexts"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)updateConfidencesFromGuesses:(NSDictionary *)guesses {
    [contexts enumerateKeysAndObjectsUsingBlock:^(NSString *uuid, Context *ctxt, BOOL *stop) {
		NSNumber *conf = guesses[uuid];
        ctxt.confidence = (conf != nil) ? (conf) : (@0);
    }];

	// XXX: hackish -- but will be enough until 3.0
    // don't force data update if we're editing a context name
	NSOutlineView *olv = [self valueForKey:@"outlineView"];
	if ([olv currentEditor] == nil) {
        [self triggerOutlineViewReloadData:nil];
    }
}

#pragma mark -
#pragma mark Context creation via sheet

- (Context *)createContextWithName:(NSString *)name fromUI:(BOOL)fromUI
{
	NSOutlineView *strongOutlineView = outlineView;
    
    Context *ctxt = [[Context alloc] init];
    ctxt.name = name;
    if (fromUI) {
        NSColorWell *strongNewContextSheetColor = newContextSheetColor;
        ctxt.iconColor = [strongNewContextSheetColor color];
    }
    
	// Look for parent
	if (fromUI && ([strongOutlineView selectedRow] >= 0)) {
        ctxt.parentUUID = [(Context *)[strongOutlineView itemAtRow:[strongOutlineView selectedRow]] uuid];
    } else {
        ctxt.parentUUID = @"";
    }
    
    contexts[ctxt.uuid] = ctxt;
    
	[self recomputeTransientData];
	[self postContextsChangedNotification];
    
	if (fromUI) {
        if (![ctxt isRoot]) {
			[strongOutlineView expandItem:contexts[ctxt.parentUUID]];
        }
		[strongOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:[strongOutlineView rowForItem:ctxt]]
                       byExtendingSelection:NO];
		[self outlineViewSelectionDidChange:nil];
	} else {
		[strongOutlineView reloadData];
    }
    
	return ctxt;
}

- (IBAction)newContextPromptingForName:(id)sender {
    NSTextField *strongNewContextSheetName = newContextSheetName;
	[strongNewContextSheetName setStringValue:NSLocalizedString(@"New context",
                                                                @"Default value for new context names")];
	[strongNewContextSheetName selectText:nil];
    
    NSColorWell *strongNewContextSheetColor = newContextSheetColor;
    [strongNewContextSheetColor setColor:[NSColor blackColor]];
    
    NSButton *strongNewContextSheetColorPreviewEnabled = newContextSheetColorPreviewEnabled;
    [strongNewContextSheetColorPreviewEnabled setIntValue:0];

	[NSApp beginSheet:newContextSheet
	   modalForWindow:prefsWindow
	    modalDelegate:self
	   didEndSelector:@selector(newContextSheetDidEnd:returnCode:contextInfo:)
	      contextInfo:nil];
}

// Triggered by OK button
- (IBAction)newContextSheetAccepted:(id)sender {
	NSPanel *strongNewContextSheet = newContextSheet;
    [NSApp endSheet:strongNewContextSheet returnCode:NSOKButton];
	[strongNewContextSheet orderOut:nil];
}

// Triggered by cancel button
- (IBAction)newContextSheetRejected:(id)sender {
	NSPanel *strongNewContextSheet = newContextSheet;
	[NSApp endSheet:strongNewContextSheet returnCode:NSCancelButton];
	[strongNewContextSheet orderOut:nil];
}

- (void)newContextSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    NSButton *strongNewContextSheetColorPreviewEnabled = newContextSheetColorPreviewEnabled;
    if ([strongNewContextSheetColorPreviewEnabled intValue]) {
        [strongNewContextSheetColorPreviewEnabled setIntValue:0];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"iconColorPreviewFinished" object:nil];
    }
    
	if (returnCode != NSOKButton) {
		return;
    }
    
    NSTextField *strongNewContextSheetName = newContextSheetName;
	[self createContextWithName:[strongNewContextSheetName stringValue] fromUI:YES];
}

- (IBAction)editSelectedContext:(id)sender
{
    NSOutlineView *strongOutlineView = outlineView;
	NSInteger row = [strongOutlineView selectedRow];
	if (row < 0) {
		return;
    }

	Context *ctxt = (Context *)[strongOutlineView itemAtRow:row];
    
    NSTextField *strongNewContextSheetName = newContextSheetName;
	[strongNewContextSheetName setStringValue:ctxt.name];
	[strongNewContextSheetName selectText:nil];
    
    NSColorWell *strongNewContextSheetColor = newContextSheetColor;
    NSColor *color = (ctxt.iconColor != nil) ? (ctxt.iconColor) : ([NSColor blackColor]);
    [strongNewContextSheetColor setColor:color];
    
    NSButton *strongNewContextSheetColorPreviewEnabled = newContextSheetColorPreviewEnabled;
    [strongNewContextSheetColorPreviewEnabled setIntValue:0];
    
	[NSApp beginSheet:newContextSheet
	   modalForWindow:prefsWindow
	    modalDelegate:self
	   didEndSelector:@selector(editContextSheetDidEnd:returnCode:contextInfo:)
	      contextInfo:nil];
}

- (void)editContextSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    NSOutlineView *strongOutlineView = outlineView;
    NSButton *strongNewContextSheetColorPreviewEnabled = newContextSheetColorPreviewEnabled;
    if ([strongNewContextSheetColorPreviewEnabled intValue]) {
        [strongNewContextSheetColorPreviewEnabled setIntValue:0];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"iconColorPreviewFinished" object:nil];
    }
    
	if (returnCode != NSOKButton) {
		return;
    }
    
	NSInteger row = [strongOutlineView selectedRow];
	if (row < 0) {
		return;
    }
    
	Context *ctxt = (Context *)[strongOutlineView itemAtRow:row];
    
    NSTextField *strongNewContextSheetName = newContextSheetName;
    ctxt.name = [strongNewContextSheetName stringValue];
    
    NSColorWell *strongNewContextSheetColor = newContextSheetColor;
    ctxt.iconColor = [strongNewContextSheetColor color];
    
	[self postContextsChangedNotification];
}

#pragma mark -

- (NSArray *)childrenOfContext:(NSString *)uuid {
	if (!uuid) {
		uuid = @"";
    }

	NSMutableArray *arr = [NSMutableArray array];

    [contexts enumerateKeysAndObjectsUsingBlock:^(id key, Context *ctxt, BOOL *stop) {
		if ([[ctxt parentUUID] isEqualToString:uuid]) {
			[arr addObject:ctxt];
        }
    }];

	[arr sortUsingSelector:@selector(compare:)];

	return arr;
}

- (void)removeContextRecursively:(NSString *)uuid {
	for (Context *ctxt in [self childrenOfContext:uuid]) {
		[self removeContextRecursively:[ctxt uuid]];
    }

	[contexts removeObjectForKey:uuid];
}

- (void)removeContextAfterAlert:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	Context *ctxt = (__bridge Context *)contextInfo;

	if (returnCode != NSAlertFirstButtonReturn) {
		return;		// cancelled
    }

	[self removeContextRecursively:[ctxt uuid]];

	[self recomputeTransientData];
	[self postContextsChangedNotification];
	[self outlineViewSelectionDidChange:nil];
}

- (IBAction)onIconColorChange:(id)sender {
    NSButton *strongNewContextSheetColorPreviewEnabled = newContextSheetColorPreviewEnabled;
    if ([strongNewContextSheetColorPreviewEnabled intValue]) {
        NSColorWell *strongNewContextSheetColor = newContextSheetColor;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"iconColorPreviewRequested"
                                                            object:nil
                                                          userInfo:@{ @"color": [strongNewContextSheetColor color] }];
    }
}

- (IBAction)onColorPreviewModeChange:(id)sender {
    NSButton *strongNewContextSheetColorPreviewEnabled = newContextSheetColorPreviewEnabled;
    if ([strongNewContextSheetColorPreviewEnabled intValue]) {
        NSColorWell *strongNewContextSheetColor = newContextSheetColor;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"iconColorPreviewRequested"
                                                            object:nil
                                                          userInfo:@{ @"color": [strongNewContextSheetColor color] }];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"iconColorPreviewFinished" object:nil];
    }
}

- (IBAction)removeContext:(id)sender
{
    NSOutlineView *strongOutlineView = outlineView;
	NSInteger row = [strongOutlineView selectedRow];
	if (row < 0) {
		return;
    }

	Context *ctxt = (Context *)[strongOutlineView itemAtRow:row];

	if ([[self childrenOfContext:[ctxt uuid]] count] > 0) {
		// Warn about destroying child contexts
		NSAlert *alert = [[NSAlert alloc] init];
		[alert setAlertStyle:NSWarningAlertStyle];
		[alert setMessageText:NSLocalizedString(@"Removing this context will also remove its child contexts!", "")];
		[alert setInformativeText:NSLocalizedString(@"This action is not undoable!", @"")];
		[alert addButtonWithTitle:NSLocalizedString(@"OK", @"")];
		[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];

		[alert beginSheetModalForWindow:prefsWindow
				  modalDelegate:self
				 didEndSelector:@selector(removeContextAfterAlert:returnCode:contextInfo:)
				    contextInfo:(__bridge void *)ctxt];
		return;
	}

	[self removeContextRecursively:[ctxt uuid]];

	[self recomputeTransientData];
	[self postContextsChangedNotification];
	[self outlineViewSelectionDidChange:nil];
}

- (Context *)contextByUUID:(NSString *)uuid {
	return [contexts objectForKey:uuid];
}

- (Context *)contextByName:(NSString *) name {
	for (NSString *key in contexts) {
		Context *value = [contexts objectForKey:key];
		
		if ([[value name] isEqualToString: name])
			return value;
	}
	
	return nil;
}

- (NSArray *)arrayOfUUIDs {
	return [contexts allKeys];
}

- (NSDictionary *) getAllContexts {
    return contexts;
}

// Private
- (void)orderedTraversalFrom:(NSString *)uuid into:(NSMutableArray *)array {
	Context *current = [contexts objectForKey:uuid];
	if (current) {
		[array addObject:current];
    }

    for (Context *child in [self childrenOfContext:uuid]) {
		[self orderedTraversalFrom:[child uuid] into:array];
    }
}

- (NSArray *)orderedTraversal {
	return [self orderedTraversalRootedAt:nil];
}

- (NSArray *)orderedTraversalRootedAt:(NSString *)uuid {
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:[contexts count]];
	[self orderedTraversalFrom:uuid into:array];
	return array;
}

// Private
- (NSMutableArray *)walkToRoot:(NSString *)uuid {
	// NOTE: There's no reason why this is limited, except for loop-avoidance.
	// If you're using more than 20-deep nested contexts, perhaps ControlPlane isn't for you?
	int limit = 20;

	NSMutableArray *walk = [NSMutableArray array];
	while (limit > 0) {
		--limit;
		Context *ctxt = [contexts objectForKey:uuid];
		if (!ctxt)
			break;
		[walk addObject:ctxt];
		uuid = [ctxt parentUUID];
	}

	return walk;
}

- (NSArray *)walkFrom:(NSString *)src_uuid to:(NSString *)dst_uuid {
	NSArray *src_walk = [self walkToRoot:src_uuid];
	NSArray *dst_walk = [self walkToRoot:dst_uuid];

	Context *common = [src_walk firstObjectCommonWithArray:dst_walk];
	if (common) {
		// Trim to minimal common walks
		src_walk = [src_walk subarrayWithRange:NSMakeRange(0, [src_walk indexOfObject:common])];
		dst_walk = [dst_walk subarrayWithRange:NSMakeRange(0, [dst_walk indexOfObject:common])];
	}

	// Reverse dst_walk so we are walking *away* from the root
	NSMutableArray *dst_walk_rev = [NSMutableArray arrayWithCapacity:[dst_walk count]];
	NSEnumerator *en = [dst_walk reverseObjectEnumerator];
	Context *ctxt;
	while ((ctxt = [en nextObject]))
		[dst_walk_rev addObject:ctxt];

	return [NSArray arrayWithObjects:src_walk, dst_walk_rev, nil];
}

- (NSString *)pathFromRootTo:(NSString *)uuid {
	NSArray *walk = [self walkToRoot:uuid];

	NSMutableArray *rev_walk = [NSMutableArray arrayWithCapacity:[walk count]];
	NSEnumerator *en = [walk reverseObjectEnumerator];
	id obj;
	while ((obj = [en nextObject]))
		[rev_walk addObject:obj];

	return [rev_walk componentsJoinedByString:@"/"];
}

- (NSMenu *)hierarchicalMenu
{
	NSMenu *menu = [[NSMenu alloc] init];
	for (Context *ctxt in [self orderedTraversal]) {
		NSMenuItem *item = [[NSMenuItem alloc] init];
		[item setTitle:ctxt.name];
		[item setIndentationLevel:[ctxt.depth intValue]];
		[item setRepresentedObject:ctxt.uuid];
		//[item setTarget:self];
		//[item setAction:@selector(forceSwitch:)];
		[menu addItem:item];
	}

	return menu;
}

#pragma mark NSOutlineViewDataSource general methods

- (id)outlineView:(NSOutlineView *)olv child:(int)index ofItem:(id)item {
	// TODO: optimise!

	NSArray *children = [self childrenOfContext:(item ? [item uuid] : @"")];
	return [children objectAtIndex:index];
}

- (NSInteger)outlineView:(NSOutlineView *)olv numberOfChildrenOfItem:(id)item {
	// TODO: optimise!
	
	NSArray *children = [self childrenOfContext:(item ? [item uuid] : @"")];
	return [children count];
}

- (BOOL)outlineView:(NSOutlineView *)olv isItemExpandable:(id)item {
	return [self outlineView:olv numberOfChildrenOfItem:item] > 0;
}

- (id)outlineView:(NSOutlineView *)olv objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	Context *ctxt = (Context *) item;
    NSString *columnId = [tableColumn identifier];
	if ([@"context" isEqualToString:columnId]) {
        NSString *name = ctxt.name;

        NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
        if ([standardUserDefaults boolForKey:@"UseDefaultContext"]) {
            NSString *uuid = [standardUserDefaults stringForKey:@"DefaultContext"];
            if ([uuid isEqualToString:ctxt.uuid]) {
                name = [name stringByAppendingString:@" (default)"];
            }
        }

		return name;
    } else if ([@"confidence" isEqualToString:columnId]) {
        NSNumber *confidence = ctxt.confidence;
        if ([confidence doubleValue] == 0.0) {
            return @"";
        }
		return [[SharedNumberFormatter percentStyleFormatter] stringFromNumber:confidence];
    }
	return nil;
}

- (void)outlineView:(NSOutlineView *)olv
     setObjectValue:(id)object
     forTableColumn:(NSTableColumn *)tableColumn
             byItem:(id)item
{
	if (![[tableColumn identifier] isEqualToString:@"context"])
		return;

	Context *ctxt = (Context *) item;
	[ctxt setName:object];

	//[self recomputeTransientData];
	[self postContextsChangedNotification];
}

#pragma mark NSOutlineViewDataSource drag-n-drop methods

- (BOOL)outlineView:(NSOutlineView *)olv acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(int)index {
	// Only support internal drags (i.e. moves)
	if ([info draggingSource] != outlineView)
		return NO;

	NSString *new_parent_uuid = @"";
	if (item)
		new_parent_uuid = [(Context *) item uuid];

	NSString *uuid = [[info draggingPasteboard] stringForType:MovedRowsType];
	Context *ctxt = [contexts objectForKey:uuid];
	[ctxt setParentUUID:new_parent_uuid];

	[self recomputeTransientData];
	[self postContextsChangedNotification];
	[self outlineViewSelectionDidChange:nil];

	return YES;
}

- (NSDragOperation)outlineView:(NSOutlineView *)olv
                  validateDrop:(id <NSDraggingInfo>)info
                  proposedItem:(id)item
            proposedChildIndex:(int)index
{
	// Only support internal drags (i.e. moves)
	if ([info draggingSource] != outlineView)
		return NSDragOperationNone;

	// Don't allow dropping on a child context
	Context *moving = [contexts objectForKey:[[info draggingPasteboard] stringForType:MovedRowsType]];
	Context *drop_on = (Context *) item;
	if (drop_on && [[self walkToRoot:[drop_on uuid]] containsObject:moving])
		return NSDragOperationNone;

	return NSDragOperationMove;
}

- (BOOL)outlineView:(NSOutlineView *)olv writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard {
	// declare our own pasteboard types
	NSArray *typesArray = [NSArray arrayWithObject:MovedRowsType];

	[pboard declareTypes:typesArray owner:self];

	// add context UUID for local move
	Context *ctxt = (Context *) [items objectAtIndex:0];
	[pboard setString:[ctxt uuid] forType:MovedRowsType];

	return YES;
}

#pragma mark NSOutlineView delegate methods

- (void)triggerOutlineViewReloadData:(NSNotification *)notification {
    NSOutlineView *strongOutlineView = outlineView;
	[strongOutlineView reloadData];
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
	Context *ctxt = nil;
    NSOutlineView *strongOutlineView = outlineView;
	NSInteger row = [strongOutlineView selectedRow];
	if (row >= 0) {
		ctxt = [strongOutlineView itemAtRow:[strongOutlineView selectedRow]];
    }
    
	[self setValue:ctxt forKey:@"selection"];
}

@end
