//
//  ContextSelectionButton.m
//  ControlPlane
//
//  Created by David Symonds on 6/07/07.
//

#import "ContextSelectionButton.h"

@implementation ContextSelectionButton {
	ContextsDataSource *contextsDataSource;
}

- (void)setSelectedObject:(id)arg
{
	if (!arg) {
		[self selectItem:nil];
		return;
	}

	NSEnumerator *en = [[self itemArray] objectEnumerator];
	NSMenuItem *item;
	while ((item = [en nextObject])) {
		NSString *uuid = [item representedObject];
		if ([uuid isEqualToString:arg]) {
			[self selectItem:item];
			break;
		}
	}
}

- (void)contextsChanged:(NSNotification *)notification
{
	// Update menu
	NSString *lastUUID = nil;
	if ([self menu]) {
		lastUUID = [[self selectedItem] representedObject];
		[[NSNotificationCenter defaultCenter] removeObserver:self
								name:nil
							      object:[self menu]];
	}
	[self setMenu:[contextsDataSource hierarchicalMenu]];
	if (lastUUID != nil) {
		[self selectItemAtIndex:[self indexOfItemWithRepresentedObject:lastUUID]];
    }
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(selectionChanged:)
						     name:NSMenuDidSendActionNotification
						   object:[self menu]];
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
	[self setValue:[item representedObject] forKey:@"selectedObject"];
}

@end
