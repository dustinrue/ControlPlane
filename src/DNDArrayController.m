// This is all addapted from mmalc's freely distributed DNDArrayController on his site.

#import "DNDArrayController.h"


NSString *MovedRowsType = @"MOVED_ROWS_TYPE";

@implementation DNDArrayController


- (void)awakeFromNib
{
	// register for drag and drop
	[tableView registerForDraggedTypes:[NSArray arrayWithObject:MovedRowsType]];

	[super awakeFromNib];
}

- (BOOL)tableView:(NSTableView *)tv writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard
{
	// declare our own pasteboard types
	NSArray *typesArray = [NSArray arrayWithObjects:MovedRowsType, nil];

	[pboard declareTypes:typesArray owner:self];

	// add rows array for local move
	[pboard setPropertyList:rows forType:MovedRowsType];

	return YES;
}

- (NSDragOperation)tableView:(NSTableView *)tv
		validateDrop:(id <NSDraggingInfo>)info
		 proposedRow:(int)row
       proposedDropOperation:(NSTableViewDropOperation)op
{
	// Only support internal drags (i.e. moves)
	if ([info draggingSource] != tableView)
		return NSDragOperationNone;

	[tv setDropRow:row dropOperation:NSTableViewDropAbove];
	return NSDragOperationMove;
}

- (BOOL)tableView:(NSTableView *)tv
       acceptDrop:(id <NSDraggingInfo>)info
	      row:(int)row
    dropOperation:(NSTableViewDropOperation)op
{
	if (row < 0)
		row = 0;

	// Only support internal drags (i.e. moves)
	if ([info draggingSource] != tableView)
		return NO;

	NSArray *rows = [[info draggingPasteboard] propertyListForType:MovedRowsType];
	NSIndexSet *indexSet = [self indexSetFromRows:rows];

	[self moveObjectsInArrangedObjectsFromIndexes:indexSet toIndex:row];

	// set selected rows to those that were just moved
	// Need to work out what moved where to determine proper selection...
	int rowsAbove = [self rowsAboveRow:row inIndexSet:indexSet];

	NSRange range = NSMakeRange(row - rowsAbove, [indexSet count]);
	indexSet = [NSIndexSet indexSetWithIndexesInRange:range];
	[self setSelectionIndexes:indexSet];

	return YES;
}

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if ([aCell class] != [NSTextFieldCell class])
		return;

	BOOL drawInGrey = NO;

	NSDictionary *thisRow = [[self arrangedObjects] objectAtIndex:rowIndex];
	NSNumber *enabled;
	if ((enabled = [thisRow objectForKey:@"enabled"]) && ![enabled boolValue])
		drawInGrey = YES;

	if (drawInGrey)
		[aCell setTextColor:[NSColor colorWithDeviceWhite:0.5 alpha:1.0]];
	else
		[aCell setTextColor:[NSColor colorWithDeviceWhite:0 alpha:1.0]];
}

#pragma mark -

- (void)moveObjectsInArrangedObjectsFromIndexes:(NSIndexSet *)indexSet toIndex:(unsigned int)insertIndex
{
	NSArray *objects = [self arrangedObjects];
	NSUInteger index = [indexSet lastIndex];

	int aboveInsertIndexCount = 0;
	id object;
	int removeIndex;

	while (index != NSNotFound) {
		if (index >= insertIndex) {
			removeIndex = index + aboveInsertIndexCount;
			aboveInsertIndexCount += 1;
		} else {
			removeIndex = index;
			insertIndex -= 1;
		}
		object = [objects objectAtIndex:removeIndex];
		[self removeObjectAtArrangedObjectIndex:removeIndex];
		[self insertObject:object atArrangedObjectIndex:insertIndex];

		index = [indexSet indexLessThanIndex:index];
	}
}

- (NSIndexSet *)indexSetFromRows:(NSArray *)rows
{
	NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
	NSEnumerator *rowEnumerator = [rows objectEnumerator];
	NSNumber *idx;
	while ((idx = [rowEnumerator nextObject]))
		[indexSet addIndex:[idx intValue]];
	return indexSet;
}


- (int)rowsAboveRow:(int)row inIndexSet:(NSIndexSet *)indexSet
{
	NSUInteger currentIndex = [indexSet firstIndex];
	int i = 0;
	while (currentIndex != NSNotFound) {
		if (currentIndex < row)
			i++;
		currentIndex = [indexSet indexGreaterThanIndex:currentIndex];
	}
	return i;
}

@end
