//
//  ContextsDataSource.m
//  ControlPlane
//
//  Created by David Symonds on 3/07/07.
//

#import "ContextsDataSource.h"


@implementation Context

- (id)init
{
	if (!(self = [super init]))
		return nil;

	CFUUIDRef ref = CFUUIDCreate(NULL);
	uuid = (NSString *) CFUUIDCreateString(NULL, ref);
	CFRelease(ref);

	parent = [[NSString alloc] init];
	name = [uuid retain];

	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	if (!(self = [super init]))
		return nil;

	uuid = [[dict valueForKey:@"uuid"] copy];
	parent = [[dict valueForKey:@"parent"] copy];
	name = [[dict valueForKey:@"name"] copy];

	return self;
}

- (void)dealloc
{
	[uuid release];
	[parent release];
	[name release];

	[super dealloc];
}

- (BOOL)isRoot
{
	return [parent length] == 0;
}

- (NSDictionary *)dictionary
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		uuid, @"uuid", parent, @"parent", name, @"name", nil];
}

- (NSComparisonResult)compare:(Context *)ctxt
{
	return [name compare:[ctxt name]];
}

- (NSString *)uuid
{
	return uuid;
}

- (NSString *)parentUUID
{
	return parent;
}

- (void)setParentUUID:(NSString *)parentUUID
{
	[parent autorelease];
	parent = [parentUUID copy];
}

- (NSString *)name
{
	return name;
}

- (void)setName:(NSString *)newName
{
	[name autorelease];
	name = [newName copy];
}

// Used by -[ContextsDataSource pathFromRootTo:]
- (NSString *)description
{
	return name;
}

- (NSString *)confidence
{
	return confidence;
}

- (void)setConfidence:(NSString *)newConfidence
{
	[confidence autorelease];
	confidence = [newConfidence copy];
}

@end

#pragma mark -
#pragma mark -

@implementation ContextsDataSource

+ (void)initialize
{
	[self exposeBinding:@"selection"];	// outlineView selection binding proxy
}

- (id)init
{
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

- (void)dealloc
{
	[contexts release];

	[super dealloc];
}

static NSString *MovedRowsType = @"MOVED_ROWS_TYPE";

- (void)awakeFromNib
{
	// register for drag and drop
	[outlineView registerForDraggedTypes:[NSArray arrayWithObject:MovedRowsType]];

	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(triggerOutlineViewReloadData:)
						     name:@"ContextsChangedNotification"
						   object:self];
}

// Private
- (void)postContextsChangedNotification
{
	[self saveContexts:self];		// make sure they're saved

	[[NSNotificationCenter defaultCenter] postNotificationName:@"ContextsChangedNotification" object:self];
}

#pragma mark -

// Private: assumes any depths already set in other contexts are correct, except when it's negative
- (void)recomputeDepthOf:(Context *)context
{
	if ([[context valueForKey:@"depth"] intValue] >= 0)
		return;

	Context *parent = [contexts objectForKey:[context parentUUID]];
	if (!parent)
		[context setValue:[NSNumber numberWithInt:0] forKey:@"depth"];
	else {
		[self recomputeDepthOf:parent];
		int depth = [[parent valueForKey:@"depth"] intValue] + 1;
		[context setValue:[NSNumber numberWithInt:depth] forKey:@"depth"];
	}
}

// Private
- (void)recomputeTransientData
{
	// Recalculate depths
	NSEnumerator *en = [contexts objectEnumerator];
	Context *ctxt;
	while ((ctxt = [en nextObject])) {
		int depth = -1;
		if ([ctxt isRoot])
			depth = 0;
		[ctxt setValue:[NSNumber numberWithInt:depth] forKey:@"depth"];
	}
	en = [contexts objectEnumerator];
	while ((ctxt = [en nextObject])) {
		if (![ctxt isRoot])
			[self recomputeDepthOf:ctxt];
	}

	// XXX: any other data to recompute?
}

#pragma mark -

- (void)loadContexts
{
	[contexts removeAllObjects];

	NSEnumerator *en = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Contexts"] objectEnumerator];
	NSDictionary *dict;
	while ((dict = [en nextObject])) {
		Context *ctxt = [[Context alloc] initWithDictionary:dict];
		[contexts setValue:ctxt forKey:[ctxt uuid]];
	}

	// Check consistency of parent UUIDs; drop the parent UUID if it is invalid
	en = [contexts objectEnumerator];
	Context *ctxt;
	while ((ctxt = [en nextObject])) {
		if (![ctxt isRoot] && ![contexts objectForKey:[ctxt parentUUID]]) {
			NSLog(@"%s correcting broken parent UUID for context '%@'", __PRETTY_FUNCTION__, [ctxt name]);
			[ctxt setParentUUID:@""];
		}
	}

	[self recomputeTransientData];
	[self postContextsChangedNotification];
}

- (void)saveContexts:(id)arg
{
	// Write out
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:[contexts count]];
	NSEnumerator *en = [contexts objectEnumerator];
	Context *ctxt;
	while ((ctxt = [en nextObject]))
		[array addObject:[ctxt dictionary]];

	[[NSUserDefaults standardUserDefaults] setObject:array forKey:@"Contexts"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark -
#pragma mark Context creation via sheet

- (Context *)newContextWithName:(NSString *)name fromUI:(BOOL)fromUI
{
	Context *ctxt = [[[Context alloc] init] autorelease];
	[ctxt setName:name];

	// Look for parent
	if (fromUI && ([outlineView selectedRow] >= 0))
		[ctxt setParentUUID:[(Context *) [outlineView itemAtRow:[outlineView selectedRow]] uuid]];
	else
		[ctxt setParentUUID:@""];


	[contexts setValue:ctxt forKey:[ctxt uuid]];

	[self recomputeTransientData];
	[self postContextsChangedNotification];

	if (fromUI) {
		if (![ctxt isRoot])
			[outlineView expandItem:[contexts objectForKey:[ctxt parentUUID]]];
		[outlineView selectRow:[outlineView rowForItem:ctxt] byExtendingSelection:NO];
		[self outlineViewSelectionDidChange:nil];
	} else
		[outlineView reloadData];

	return ctxt;
}

- (IBAction)newContextPromptingForName:(id)sender
{
	[newContextSheetName setStringValue:NSLocalizedString(@"New context", @"Default value for new context names")];
	[newContextSheetName selectText:nil];

	[NSApp beginSheet:newContextSheet
	   modalForWindow:prefsWindow
	    modalDelegate:self
	   didEndSelector:@selector(newContextSheetDidEnd:returnCode:contextInfo:)
	      contextInfo:nil];
}

// Triggered by OK button
- (IBAction)newContextSheetAccepted:(id)sender
{
	[NSApp endSheet:newContextSheet returnCode:NSOKButton];
	[newContextSheet orderOut:nil];
}

// Triggered by cancel button
- (IBAction)newContextSheetRejected:(id)sender
{
	[NSApp endSheet:newContextSheet returnCode:NSCancelButton];
	[newContextSheet orderOut:nil];
}

// Private
- (void)newContextSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode != NSOKButton)
		return;

	[self newContextWithName:[newContextSheetName stringValue] fromUI:YES];
}

#pragma mark -

// Private
- (NSArray *)childrenOfContext:(NSString *)uuid
{
	NSMutableArray *arr = [NSMutableArray array];

	if (!uuid)
		uuid = @"";

	NSEnumerator *en = [contexts objectEnumerator];
	Context *ctxt;
	while ((ctxt = [en nextObject]))
		if ([[ctxt parentUUID] isEqualToString:uuid])
			[arr addObject:ctxt];

	[arr sortUsingSelector:@selector(compare:)];

	return arr;
}

// Private: Make sure you call [outlineView reloadData] after this!
- (void)removeContextRecursively:(NSString *)uuid
{
	NSEnumerator *en = [[self childrenOfContext:uuid] objectEnumerator];
	Context *ctxt;
	while ((ctxt = [en nextObject]))
		[self removeContextRecursively:[ctxt uuid]];

	[contexts removeObjectForKey:uuid];
}

// Private
- (void)removeContextAfterAlert:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	Context *ctxt = (Context *) contextInfo;

	if (returnCode != NSAlertFirstButtonReturn)
		return;		// cancelled

	[self removeContextRecursively:[ctxt uuid]];

	[self recomputeTransientData];
	[self postContextsChangedNotification];
	[self outlineViewSelectionDidChange:nil];
}

- (IBAction)removeContext:(id)sender
{
	int row = [outlineView selectedRow];
	if (row < 0)
		return;

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

- (Context *)contextByUUID:(NSString *)uuid
{
	return [contexts objectForKey:uuid];
}

- (NSArray *)arrayOfUUIDs
{
	return [contexts allKeys];
}

// Private
- (void)orderedTraversalFrom:(NSString *)uuid into:(NSMutableArray *)array
{
	Context *ctxt = [contexts objectForKey:uuid];
	if (ctxt)
		[array addObject:ctxt];
	NSEnumerator *en = [[self childrenOfContext:uuid] objectEnumerator];
	while ((ctxt = [en nextObject]))
		[self orderedTraversalFrom:[ctxt uuid] into:array];
}

- (NSArray *)orderedTraversal
{
	return [self orderedTraversalRootedAt:nil];
}

- (NSArray *)orderedTraversalRootedAt:(NSString *)uuid
{
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:[contexts count]];
	[self orderedTraversalFrom:uuid into:array];
	return array;
}

// Private
- (NSMutableArray *)walkToRoot:(NSString *)uuid
{
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

- (NSArray *)walkFrom:(NSString *)src_uuid to:(NSString *)dst_uuid
{
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

- (NSString *)pathFromRootTo:(NSString *)uuid
{
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
	NSMenu *menu = [[[NSMenu alloc] init] autorelease];
	NSEnumerator *en = [[self orderedTraversal] objectEnumerator];
	Context *ctxt;
	while ((ctxt = [en nextObject])) {
		NSMenuItem *item = [[[NSMenuItem alloc] init] autorelease];
		[item setTitle:[ctxt name]];
		[item setIndentationLevel:[[ctxt valueForKey:@"depth"] intValue]];
		[item setRepresentedObject:[ctxt uuid]];
		//[item setTarget:self];
		//[item setAction:@selector(forceSwitch:)];
		[menu addItem:item];
	}

	return menu;
}

#pragma mark NSOutlineViewDataSource general methods

- (id)outlineView:(NSOutlineView *)olv child:(int)index ofItem:(id)item
{
	// TODO: optimise!

	NSArray *children = [self childrenOfContext:(item ? [item uuid] : @"")];
	return [children objectAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)olv isItemExpandable:(id)item
{
	return [self outlineView:olv numberOfChildrenOfItem:item] > 0;
}

- (int)outlineView:(NSOutlineView *)olv numberOfChildrenOfItem:(id)item
{
	// TODO: optimise!

	NSArray *children = [self childrenOfContext:(item ? [item uuid] : @"")];
	return [children count];
}

- (id)outlineView:(NSOutlineView *)olv objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	Context *ctxt = (Context *) item;
	if ([[tableColumn identifier] isEqualToString:@"context"])
		return [ctxt name];
	else if ([[tableColumn identifier] isEqualToString:@"confidence"])
		return [ctxt valueForKey:@"confidence"];
	return nil;
}

- (void)outlineView:(NSOutlineView *)olv setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if (![[tableColumn identifier] isEqualToString:@"context"])
		return;

	Context *ctxt = (Context *) item;
	[ctxt setName:object];

	//[self recomputeTransientData];
	[self postContextsChangedNotification];
}

#pragma mark NSOutlineViewDataSource drag-n-drop methods

- (BOOL)outlineView:(NSOutlineView *)olv acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(int)index
{
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

- (NSDragOperation)outlineView:(NSOutlineView *)olv validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(int)index
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

- (BOOL)outlineView:(NSOutlineView *)olv writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard
{
	// declare our own pasteboard types
	NSArray *typesArray = [NSArray arrayWithObject:MovedRowsType];

	[pboard declareTypes:typesArray owner:self];

	// add context UUID for local move
	Context *ctxt = (Context *) [items objectAtIndex:0];
	[pboard setString:[ctxt uuid] forType:MovedRowsType];

	return YES;
}

#pragma mark NSOutlineView delegate methods

- (void)triggerOutlineViewReloadData:(NSNotification *)notification
{
	[outlineView reloadData];
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	Context *ctxt = nil;
	int row = [outlineView selectedRow];
	if (row >= 0)
		ctxt = [outlineView itemAtRow:[outlineView selectedRow]];

	[self setValue:ctxt forKey:@"selection"];
}

@end
