//
//  ContextsDataSource.m
//  ControlPlane
//
//  Created by David Symonds on 3/07/07.
//

#import "ContextsDataSource.h"
#import "CPController.h"
#import "DSLogger.h"

@interface Context ()

// Transient
@property (retain,nonatomic,readwrite) NSNumber *depth;

@end

@implementation Context

@synthesize uuid = _uuid;

- (id)init {
	if (!(self = [super init])) {
		return nil;
    }

	CFUUIDRef ref = CFUUIDCreate(NULL);
	_uuid = (NSString *) CFUUIDCreateString(NULL, ref);
	CFRelease(ref);

	_parentUUID = [[NSString alloc] init];
	_name = [_uuid copy];

	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict {
	if (!(self = [super init])) {
		return nil;
    }

	_uuid = [dict[@"uuid"] copy];
	_parentUUID = [dict[@"parent"] copy];
	_name = [dict[@"name"] copy];

    NSData *colorData = dict[@"iconColor"];
    if (colorData) {
        _iconColor = [(NSColor *) [NSUnarchiver unarchiveObjectWithData:colorData] copy];
    }

	return self;
}

- (void)dealloc {
	[_depth release];
    [_confidence release];
    [_iconColor release];
	[_name release];
	[_parentUUID release];
    [_uuid release];

	[super dealloc];
}

- (BOOL)isRoot {
	return ([self.parentUUID length] == 0);
}

- (NSDictionary *)dictionary {
    if (!(self.iconColor) || [self.iconColor isEqualTo:[NSColor blackColor]]) { // black is the default value
        return @{ @"uuid": self.uuid, @"parent": self.parentUUID, @"name": self.name };
    }

    NSData *colorData = [NSArchiver archivedDataWithRootObject:(self.iconColor)];
    return @{ @"uuid": self.uuid, @"parent": self.parentUUID, @"name": self.name, @"iconColor": colorData };
}

- (NSComparisonResult)compare:(Context *)ctxt {
	return [self.name compare:[ctxt name]];
}

// Used by -[ContextsDataSource pathFromRootTo:]
- (NSString *)description {
	return self.name;
}

@end

#pragma mark -
#pragma mark -

@interface ContextsDataSource (Private)

- (void)newContextSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

@end

@implementation ContextsDataSource

+ (void)initialize {
	[self exposeBinding:@"selection"];	// outlineView selection binding proxy
}

- (id)init {
	if (!(self = [super init]))
		return nil;

	contexts = [[NSMutableDictionary alloc] init];
	[self loadContexts];

	// Make sure we get to save out the contexts
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(saveContexts:)
						     name:NSApplicationWillTerminateNotification
						   object:nil];

	return self;
}

- (void)dealloc {
	[contexts release];

	[super dealloc];
}

static NSString *MovedRowsType = @"MOVED_ROWS_TYPE";

- (void)awakeFromNib {
	// register for drag and drop
	[outlineView registerForDraggedTypes:[NSArray arrayWithObject:MovedRowsType]];

	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(triggerOutlineViewReloadData:)
						     name:@"ContextsChangedNotification"
						   object:self];
}

// Private
- (void)postContextsChangedNotification {
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

- (void)loadContexts {
	[contexts removeAllObjects];

	for (NSDictionary *dict in [[NSUserDefaults standardUserDefaults] objectForKey:@"Contexts"]) {
		Context *ctxt = [[Context alloc] initWithDictionary:dict];
		[contexts setValue:ctxt forKey:[ctxt uuid]];
		[ctxt release];
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

#pragma mark -
#pragma mark Context creation via sheet

- (Context *)createContextWithName:(NSString *)name fromUI:(BOOL)fromUI {
	Context *ctxt = [[[Context alloc] init] autorelease];
    ctxt.name = name;
    if (fromUI) {
        ctxt.iconColor = [newContextSheetColor color];
    }

	// Look for parent
	if (fromUI && ([outlineView selectedRow] >= 0)) {
        ctxt.parentUUID = [(Context *) [outlineView itemAtRow:[outlineView selectedRow]] uuid];
    } else {
        ctxt.parentUUID = @"";
    }

    contexts[ctxt.uuid] = ctxt;

	[self recomputeTransientData];
	[self postContextsChangedNotification];

	if (fromUI) {
        if (![ctxt isRoot]) {
			[outlineView expandItem:contexts[ctxt.parentUUID]];
        }
		[outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:[outlineView rowForItem:ctxt]] byExtendingSelection:NO];
		[self outlineViewSelectionDidChange:nil];
	} else
		[outlineView reloadData];

	return ctxt;
}

- (IBAction)newContextPromptingForName:(id)sender {
	[newContextSheetName setStringValue:NSLocalizedString(@"New context", @"Default value for new context names")];
	[newContextSheetName selectText:nil];
    [newContextSheetColor setColor:[NSColor blackColor]];
    [newContextSheetColorPreviewEnabled setIntValue:0];

	[NSApp beginSheet:newContextSheet
	   modalForWindow:prefsWindow
	    modalDelegate:self
	   didEndSelector:@selector(newContextSheetDidEnd:returnCode:contextInfo:)
	      contextInfo:nil];
}

// Triggered by OK button
- (IBAction)newContextSheetAccepted:(id)sender {
	[NSApp endSheet:newContextSheet returnCode:NSOKButton];
	[newContextSheet orderOut:nil];
}

// Triggered by cancel button
- (IBAction)newContextSheetRejected:(id)sender {
	[NSApp endSheet:newContextSheet returnCode:NSCancelButton];
	[newContextSheet orderOut:nil];
}

// Private
- (void)newContextSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    if ([newContextSheetColorPreviewEnabled intValue]) {
        [newContextSheetColorPreviewEnabled setIntValue:0];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"iconColorPreviewFinished" object:nil];
    }

	if (returnCode != NSOKButton) {
		return;
    }

	[self createContextWithName:[newContextSheetName stringValue] fromUI:YES];
}

- (IBAction)editSelectedContext:(id)sender {
	NSInteger row = [outlineView selectedRow];
	if (row < 0) {
		return;
    }

	Context *ctxt = (Context *) [outlineView itemAtRow:row];

	[newContextSheetName setStringValue:ctxt.name];
	[newContextSheetName selectText:nil];
    [newContextSheetColor setColor:(ctxt.iconColor) ? (ctxt.iconColor) : ([NSColor blackColor])];
    [newContextSheetColorPreviewEnabled setIntValue:0];

	[NSApp beginSheet:newContextSheet
	   modalForWindow:prefsWindow
	    modalDelegate:self
	   didEndSelector:@selector(editContextSheetDidEnd:returnCode:contextInfo:)
	      contextInfo:nil];
}

- (void)editContextSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    if ([newContextSheetColorPreviewEnabled intValue]) {
        [newContextSheetColorPreviewEnabled setIntValue:0];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"iconColorPreviewFinished" object:nil];
    }

	if (returnCode != NSOKButton) {
		return;
    }

	NSInteger row = [outlineView selectedRow];
	if (row < 0) {
		return;
    }

	Context *ctxt = (Context *) [outlineView itemAtRow:row];
    ctxt.name = [newContextSheetName stringValue];
    ctxt.iconColor = [newContextSheetColor color];

	[self postContextsChangedNotification];
}

#pragma mark -

// Private
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

// Private: Make sure you call [outlineView reloadData] after this!
- (void)removeContextRecursively:(NSString *)uuid {
	NSEnumerator *en = [[self childrenOfContext:uuid] objectEnumerator];
	Context *ctxt;
	while ((ctxt = [en nextObject]))
		[self removeContextRecursively:[ctxt uuid]];

	[contexts removeObjectForKey:uuid];
}

// Private
- (void)removeContextAfterAlert:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	Context *ctxt = (Context *) contextInfo;

	if (returnCode != NSAlertFirstButtonReturn)
		return;		// cancelled

	[self removeContextRecursively:[ctxt uuid]];

	[self recomputeTransientData];
	[self postContextsChangedNotification];
	[self outlineViewSelectionDidChange:nil];
}

- (IBAction)onIconColorChange:(id)sender {
    if ([newContextSheetColorPreviewEnabled intValue]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"iconColorPreviewRequested"
                                                            object:nil
                                                          userInfo:@{ @"color": [newContextSheetColor color] }];
    }
}

- (IBAction)onColorPreviewModeChange:(id)sender {
    if ([newContextSheetColorPreviewEnabled intValue]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"iconColorPreviewRequested"
                                                            object:nil
                                                          userInfo:@{ @"color": [newContextSheetColor color] }];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"iconColorPreviewFinished" object:nil];
    }
}

- (IBAction)removeContext:(id)sender {
	NSInteger row = [outlineView selectedRow];
	if (row < 0) {
		return;
    }

	Context *ctxt = (Context *) [outlineView itemAtRow:row];

	if ([[self childrenOfContext:[ctxt uuid]] count] > 0) {
		// Warn about destroying child contexts
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert setAlertStyle:NSWarningAlertStyle];
		[alert setMessageText:NSLocalizedString(@"Removing this context will also remove its child contexts!", "")];
		[alert setInformativeText:NSLocalizedString(@"This action is not undoable!", @"")];
		[alert addButtonWithTitle:NSLocalizedString(@"OK", @"")];
		[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];

		[alert beginSheetModalForWindow:prefsWindow
				  modalDelegate:self
				 didEndSelector:@selector(removeContextAfterAlert:returnCode:contextInfo:)
				    contextInfo:ctxt];
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

- (NSMenu *)hierarchicalMenu {
	NSMenu *menu = [[[NSMenu alloc] init] autorelease];
	for (Context *ctxt in [self orderedTraversal]) {
		NSMenuItem *item = [[[NSMenuItem alloc] init] autorelease];
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
	if ([[tableColumn identifier] isEqualToString:@"context"]) {
		return ctxt.name;
    } else if ([[tableColumn identifier] isEqualToString:@"confidence"]) {
		return ctxt.confidence;
    }
	return nil;
}

- (void)outlineView:(NSOutlineView *)olv
     setObjectValue:(id)object
     forTableColumn:(NSTableColumn *)tableColumn
             byItem:(id)item {

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
            proposedChildIndex:(int)index {

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
	[outlineView reloadData];
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
	Context *ctxt = nil;
	NSInteger row = [outlineView selectedRow];
	if (row >= 0)
		ctxt = [outlineView itemAtRow:[outlineView selectedRow]];

	[self setValue:ctxt forKey:@"selection"];
}

@end
