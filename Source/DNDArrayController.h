
#import <Cocoa/Cocoa.h>


@interface DNDArrayController : NSArrayController
{
	IBOutlet NSTableView *tableView;
}

// table view drag and drop support
- (BOOL)tableView:(NSTableView *)tv writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard;
- (NSDragOperation)tableView:(NSTableView *)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op;
- (BOOL)tableView:(NSTableView *)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)op;


// utility methods
- (void)moveObjectsInArrangedObjectsFromIndexes:(NSIndexSet *)indexSet toIndex:(NSUInteger)index;
- (NSIndexSet *)indexSetFromRows:(NSArray *)rows;
- (NSUInteger)rowsAboveRow:(NSUInteger)row inIndexSet:(NSIndexSet *)indexSet;

@end
