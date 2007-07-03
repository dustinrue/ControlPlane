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

	return self;
}

- (void)dealloc
{
	// TODO: write out

	[contexts release];

	[super dealloc];
}

- (void)loadContexts
{
	// XXX: should we save them first, or something?
	[contexts removeAllObjects];

	NSEnumerator *en = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Contexts"] objectEnumerator];
	NSDictionary *dict;
	while ((dict = [en nextObject])) {
		Context *ctxt = [[Context alloc] initWithDictionary:dict];
		[contexts setValue:ctxt forKey:[ctxt name]];
	}
}

- (IBAction)newContext:(id)sender
{
	NSLog(@"%s from sender=%@", __PRETTY_FUNCTION__, sender);
	Context *ctxt = [[[Context alloc] init] autorelease];

	[contexts setValue:ctxt forKey:[ctxt name]];
	[outlineView reloadData];
}

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
	NSLog(@"%s index=%d, item=%@", __PRETTY_FUNCTION__, index, item);
	// TODO: optimise!
	// TODO: handle non-root items

	NSEnumerator *en = [contexts objectEnumerator];
	Context *ctxt;
	int skip = 0;
	while ((ctxt = [en nextObject])) {
		if (skip < index) {
			++skip;
			continue;
		}
		break;
	}
	if (!ctxt) {
		NSLog(@"%s oops -- ran off end of list?", __PRETTY_FUNCTION__);
		return nil;	// safety
	}

	return ctxt;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	// TODO
	return NO;
}

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	NSLog(@"%s item=%@", __PRETTY_FUNCTION__, item);
	// TODO: optimise!

	// TODO: handle non-root items
	if (item)
		return 0;

	NSEnumerator *en = [contexts objectEnumerator];
	Context *ctxt;
	int cnt = 0;
	while ((ctxt = [en nextObject])) {
		// TODO: handle non-root items
		++cnt;
	}

	return cnt;
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
