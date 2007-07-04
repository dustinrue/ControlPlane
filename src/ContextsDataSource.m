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

- (NSString *)uuid
{
	return uuid;
}

- (NSString *)parent
{
	return parent;
}

- (void)setParent:(NSString *)parentUUID
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

- (void)loadContexts
{
	[contexts removeAllObjects];

	NSEnumerator *en = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Contexts"] objectEnumerator];
	NSDictionary *dict;
	while ((dict = [en nextObject])) {
		Context *ctxt = [[Context alloc] initWithDictionary:dict];
		[contexts setValue:ctxt forKey:[ctxt name]];
	}

	// TODO: check consistency of parent UUIDs?
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

	[contexts setValue:ctxt forKey:[ctxt name]];
	[outlineView reloadData];
}

- (NSArray *)childrenOf:(NSString *)parent_uuid
{
	NSMutableArray *arr = [NSMutableArray array];

	NSEnumerator *en = [contexts objectEnumerator];
	Context *ctxt;
	while ((ctxt = [en nextObject]))
		if ([[ctxt parent] isEqualToString:parent_uuid])
			[arr addObject:ctxt];

	return arr;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
	// TODO: optimise!

	NSArray *children = [self childrenOf:(item ? [item uuid] : @"")];
	if ([children count] < index + 1) {
		NSLog(@"%s oops -- ran off end of list?", __PRETTY_FUNCTION__);
		return nil;	// safety
	}

	return [children objectAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	// TODO: should this vary?
	return YES;
}

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	// TODO: optimise!

	NSArray *children = [self childrenOf:(item ? [item uuid] : @"")];
	return [children count];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	// Should only be one column: the name
	Context *ctxt = (Context *) item;
	return [ctxt name];
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	// Should only be one column: the name
	Context *ctxt = (Context *) item;
	[ctxt setName:object];
}

@end
