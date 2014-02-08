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
@property (copy,nonatomic,readwrite) NSNumber *confidence;
@property (retain,nonatomic,readonly) NSNumber *depth;

- (id)init;
- (id)initWithDictionary:(NSDictionary *)dict;

- (BOOL)isRoot;
- (NSDictionary *)dictionary;
- (NSComparisonResult)compare:(Context *)ctxt;

@end


@class SliderWithValue;

@interface ContextsDataSource : NSObject {
	NSMutableDictionary *contexts;

    IBOutlet NSButton *generalPreferencesEnableSwitching;
    IBOutlet NSButton *generalPreferencesStartAtLogin;
    IBOutlet NSButton *generalPreferencesUseNotifications;
    IBOutlet NSButton *generalPreferencesCheckForUpdates;
    IBOutlet NSButton *generalPreferencesHideFromStatusBar;
    IBOutlet NSPopUpButton *generalPreferencesShowInStatusBar;
    IBOutlet NSButton *generalPreferencesSwitchSmoothing;
    IBOutlet NSButton *generalPreferencesRestorePreviousContext;
    IBOutlet NSButton *generalPreferencesUseDefaultContextTextField;
    IBOutlet NSTextField *generalPreferencesCRtSTextField;
    IBOutlet SliderWithValue *generalPreferencesConfidenceSlider;
    
    
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

- (void)updateConfidencesFromGuesses:(NSDictionary *)guesses;

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
- (NSArray *)walkToRoot:(NSString *)uuid;
- (NSArray *)walkFrom:(NSString *)src_uuid to:(NSString *)dst_uuid;
- (NSString *)pathFromRootTo:(NSString *)uuid;
- (NSMenu *)hierarchicalMenu;

- (void)triggerOutlineViewReloadData:(NSNotification *)notification;

@end
