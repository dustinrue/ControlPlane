//
//  ContextsDataSource.h
//  ControlPlane
//
//  Created by David Symonds on 3/07/07.
//

#import <Cocoa/Cocoa.h>


@interface Context : NSObject {
	NSString *uuid;
	NSString *parent;	// UUID
	NSString *name;

	// Transient
	NSNumber *depth;
	NSString *confidence;
}

- (id)init;
- (id)initWithDictionary:(NSDictionary *)dict;

- (BOOL)isRoot;
- (NSDictionary *)dictionary;
- (NSComparisonResult)compare:(Context *)ctxt;

- (NSString *)uuid;
- (NSString *)parentUUID;
- (void)setParentUUID:(NSString *)parentUUID;
- (NSString *)name;
- (void)setName:(NSString *)newName;

@end


@interface ContextsDataSource : NSObject {
	NSMutableDictionary *contexts;

	// shouldn't _really_ be here
	IBOutlet NSOutlineView *outlineView;
	Context *selection;

	IBOutlet NSWindow *prefsWindow;
	IBOutlet NSPanel *newContextSheet;
	IBOutlet NSTextField *newContextSheetName;
}

- (void)loadContexts;
- (void)saveContexts:(id)arg;
- (Context *)newContextWithName:(NSString *)name fromUI:(BOOL)fromUI;

- (IBAction)newContextPromptingForName:(id)sender;
- (IBAction)newContextSheetAccepted:(id)sender;
- (IBAction)newContextSheetRejected:(id)sender;
- (IBAction)removeContext:(id)sender;

- (Context *)contextByUUID:(NSString *)uuid;
- (NSArray *)arrayOfUUIDs;
- (NSArray *)orderedTraversal;
- (NSArray *)orderedTraversalRootedAt:(NSString *)uuid;
- (NSArray *)walkFrom:(NSString *)src_uuid to:(NSString *)dst_uuid;
- (NSString *)pathFromRootTo:(NSString *)uuid;
- (NSMenu *)hierarchicalMenu;

- (void)triggerOutlineViewReloadData:(NSNotification *)notification;

@end
