//
//  ContextSelectionButton.m
//  MarcoPolo
//
//  Created by David Symonds on 6/07/07.
//

#import "ContextSelectionButton.h"


@implementation ContextSelectionButton

//+ (void)initialize
//{
//	[self exposeBinding:@"selectedObject"];
//}

- (id)init
{
	if (!(self = [super init]))
		return nil;

	contextsDataSource = nil;
//	selectedObject = nil;

	return self;
}

//- (id)selectedObject
//{
//	return [[[self selectedItem] representedObject] uuid];
//}

- (void)setSelectedObject:(id)arg
{
	if (!arg) {
//		[self willChangeValueForKey:@"selectedObject"];
		[self selectItem:nil];
		[self setEnabled:NO];
//		selectedObject = nil;
//		[self didChangeValueForKey:@"selectedObject"];
		return;
	}

	NSLog(@"%s set to -> %@", __PRETTY_FUNCTION__, [[contextsDataSource contextByUUID:arg] name]);

	NSEnumerator *en = [[self itemArray] objectEnumerator];
	NSMenuItem *item;
	while ((item = [en nextObject])) {
		NSString *uuid = [item representedObject];
		if ([uuid isEqualToString:arg]) {
//			[self willChangeValueForKey:@"selectedUUID"];
			[self selectItem:item];
			[self setEnabled:YES];
//			selectedObject = arg;
//			[self didChangeValueForKey:@"selectedUUID"];
			break;
		}
	}

	// Push it through
	//[arrayController setValue:[ctxt uuid] forKeyPath:@"selection.context"];
}

- (void)contextsChanged:(NSNotification *)notification
{
	NSLog(@"%s ooh, refresh!", __PRETTY_FUNCTION__);
	// Update menu
	if ([self menu]) {
		[[NSNotificationCenter defaultCenter] removeObserver:self
								name:nil
							      object:[self menu]];
	}
	[self setMenu:[contextsDataSource hierarchicalMenu]];
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(selectionChanged:)
						     name:@"NSMenuDidSendActionNotification"
						   object:[self menu]];

	// TODO: update selection
}

- (void)setContextsDataSource:(ContextsDataSource *)dataSource
{
	contextsDataSource = dataSource;

	// Watch for notifications of context changes
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(contextsChanged:)
						     name:@"ContextsChangedNotification"
						   object:contextsDataSource];
	[self contextsChanged:nil];
}

- (void)selectionChanged:(NSNotification *)notification
{
	NSMenuItem *item = [[notification userInfo] objectForKey:@"MenuItem"];
	NSLog(@"%s ooh, it works? (%@)", __PRETTY_FUNCTION__, [item representedObject]);
	//[self setValue:[[item representedObject] uuid] forKey:@"selectedUUID"];
	[self setValue:[item representedObject] forKey:@"selectedObject"];
}

@end
