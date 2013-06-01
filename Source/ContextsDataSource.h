//
//  ContextsDataSource.h
//  ControlPlane
//
//  Created by David Symonds on 3/07/07.
//


@interface Context : NSObject

// Persistent
@property (assign,nonatomic,readonly) NSString *uuid;
@property (copy,nonatomic,readwrite) NSString *parentUUID;
@property (copy,nonatomic,readwrite) NSString *name;
@property (copy,nonatomic,readwrite) NSColor  *iconColor;

// Transient
@property (copy,nonatomic,readwrite) NSString *confidence;
@property (retain,nonatomic,readonly) NSNumber *depth;

- (id)init;
- (id)initWithDictionary:(NSDictionary *)dict;

- (BOOL)isRoot;
- (NSDictionary *)dictionary;
- (NSComparisonResult)compare:(Context *)ctxt;

@end


@interface ContextsDataSource : NSObject {
	NSMutableDictionary *contexts;

	// shouldn't _really_ be here
	IBOutlet NSOutlineView *outlineView;
	Context *selection;

	IBOutlet NSWindow *prefsWindow;

	IBOutlet NSPanel *newContextSheet;
	IBOutlet NSTextField *newContextSheetName;
    IBOutlet NSColorWell *newContextSheetColor;
    IBOutlet NSButton *newContextSheetColorPreviewEnabled;
}

- (void)loadContexts;
- (void)saveContexts:(id)arg;
- (Context *)createContextWithName:(NSString *)name fromUI:(BOOL)fromUI;

- (IBAction)newContextPromptingForName:(id)sender;
- (IBAction)newContextSheetAccepted:(id)sender;
- (IBAction)newContextSheetRejected:(id)sender;
- (IBAction)removeContext:(id)sender;

- (Context *)contextByUUID:(NSString *)uuid;
- (Context *)contextByName:(NSString *)name;
- (NSArray *)arrayOfUUIDs;
- (NSArray *)orderedTraversal;
- (NSArray *)orderedTraversalRootedAt:(NSString *)uuid;
- (NSArray *)walkFrom:(NSString *)src_uuid to:(NSString *)dst_uuid;
- (NSString *)pathFromRootTo:(NSString *)uuid;
- (NSMenu *)hierarchicalMenu;

- (void)triggerOutlineViewReloadData:(NSNotification *)notification;

@end
