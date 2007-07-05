//
//  ContextsDataSource.m
//  MarcoPolo
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

@end


@implementation ContextsDataSource

+ (void)initialize
{
	[self exposeBinding:@"selection"];
}

- (id)init
{
	if (!(self = [super init]))
		return nil;

	contexts = [[NSMutableDictionary alloc] init];
	[self loadContexts];

	// TODO: setup notifications to make sure we see relevant changes?

	// Make sure we get to save out the contexts
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(saveContexts:)
						     name:@"NSApplicationWillTerminateNotification"
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
}

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
}

- (IBAction)newContext:(id)sender
{
	Context *ctxt = [[[Context alloc] init] autorelease];

	[contexts setValue:ctxt forKey:[ctxt uuid]];
	[outlineView reloadData];
}

- (void)newContextWithName:(NSString *)name
{
	Context *ctxt = [[[Context alloc] init] autorelease];
	[ctxt setName:name];

	[contexts setValue:ctxt forKey:[ctxt uuid]];
	[outlineView reloadData];
}

- (NSArray *)childrenOf:(NSString *)parent_uuid
{
	NSMutableArray *arr = [NSMutableArray array];

	NSEnumerator *en = [contexts objectEnumerator];
	Context *ctxt;
	while ((ctxt = [en nextObject]))
		if ([[ctxt parentUUID] isEqualToString:parent_uuid])
			[arr addObject:ctxt];

	[arr sortUsingSelector:@selector(compare:)];

	return arr;
}

// Make sure you call [outlineView reloadData] after this!
- (void)removeContextRecursively:(NSString *)uuid
{
	NSEnumerator *en = [[self childrenOf:uuid] objectEnumerator];
	Context *ctxt;
	while ((ctxt = [en nextObject]))
		[self removeContextRecursively:[ctxt uuid]];

	[contexts removeObjectForKey:uuid];
}

- (IBAction)removeContext:(id)sender
{
	int row = [outlineView selectedRow];
	if (row < 0)
		return;

	Context *ctxt = (Context *) [outlineView itemAtRow:[outlineView selectedRow]];

	if ([[self childrenOf:[ctxt uuid]] count] > 0) {
		// Warn about destroying child contexts
		NSAlert *alert = [[NSAlert alloc] init];
		[alert setAlertStyle:NSWarningAlertStyle];
		[alert setMessageText:NSLocalizedString(@"Removing this context will also remove its child contexts!", "")];
		[alert setInformativeText:NSLocalizedString(@"This action is not undoable!", @"")];
		[alert addButtonWithTitle:NSLocalizedString(@"OK", @"")];
		[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];

		if ([alert runModal] != NSAlertFirstButtonReturn)
			return;
	}

	[self removeContextRecursively:[ctxt uuid]];
	[outlineView reloadData];
	[self outlineViewSelectionDidChange:nil];
}

#pragma mark NSOutlineViewDataSource general methods

- (id)outlineView:(NSOutlineView *)olv child:(int)index ofItem:(id)item
{
	// TODO: optimise!

	NSArray *children = [self childrenOf:(item ? [item uuid] : @"")];
	return [children objectAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)olv isItemExpandable:(id)item
{
	return [self outlineView:olv numberOfChildrenOfItem:item] > 0;
}

- (int)outlineView:(NSOutlineView *)olv numberOfChildrenOfItem:(id)item
{
	// TODO: optimise!

	NSArray *children = [self childrenOf:(item ? [item uuid] : @"")];
	return [children count];
}

- (id)outlineView:(NSOutlineView *)olv objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	// Should only be one column: the name
	Context *ctxt = (Context *) item;
	return [ctxt name];
}

- (void)outlineView:(NSOutlineView *)olv setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	// Should only be one column: the name
	Context *ctxt = (Context *) item;
	[ctxt setName:object];

	[outlineView reloadData];
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
	[outlineView reloadData];
	[self outlineViewSelectionDidChange:nil];

	return YES;
}

- (NSDragOperation)outlineView:(NSOutlineView *)olv validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(int)index
{
	// Only support internal drags (i.e. moves)
	if ([info draggingSource] != outlineView)
		return NSDragOperationNone;

	return NSDragOperationMove;	
}

- (BOOL)outlineView:(NSOutlineView *)olv writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard
{
	// declare our own pasteboard types
	NSArray *typesArray = [NSArray arrayWithObject:MovedRowsType];

	[pboard declareTypes:typesArray owner:self];

	// add context UUID for local move
	// (TODO: work with multiple contexts?)
	Context *ctxt = (Context *) [items objectAtIndex:0];
	[pboard setString:[ctxt uuid] forType:MovedRowsType];

	return YES;
}

#pragma mark NSOutlineView delegate methods

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	Context *ctxt = nil;
	int row = [outlineView selectedRow];
	if (row >= 0)
		ctxt = [outlineView itemAtRow:[outlineView selectedRow]];
	
	[self setValue:ctxt forKey:@"selection"];
}

@end
