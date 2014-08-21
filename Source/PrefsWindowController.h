/* PrefsWindowController */

#import "ContextSelectionButton.h"
#import "CPController.h"

@interface PrefsWindowController : NSWindowController<NSToolbarDelegate>
{
	IBOutlet NSWindow *prefsWindow;
	IBOutlet NSView *generalPrefsView, *contextsPrefsView, *evidenceSourcesPrefsView,
			*rulesPrefsView, *actionsPrefsView, *advancedPrefsView;
	NSString *currentPrefsGroup;
	NSView *currentPrefsView;
	NSArray *prefsGroups;
	NSToolbar *prefsToolbar;

	IBOutlet EvidenceSourceSetController *evidenceSources;
	IBOutlet ContextsDataSource *contextsDataSource;
	IBOutlet NSArrayController *rulesController, *actionsController;
	IBOutlet NSArrayController *whenActionController;
    IBOutlet NSArrayController *menuBarDisplayOptionsController;

	// Selection controls for rules/actions
	IBOutlet ContextSelectionButton *defaultContextButton;
	IBOutlet ContextSelectionButton *editActionContextButton;

	// New action creation hooks
	IBOutlet NSWindow *newActionWindow;
	NSString *newActionType, *newActionTypeString;
	NSString *newActionWindowHelpText;
	IBOutlet NSView *newActionWindowParameterView;
	NSView *newActionWindowParameterViewCurrentControl;
	IBOutlet NSArrayController *newActionLimitedOptionsController;
	IBOutlet NSPopUpButton *newActionContext;
	NSString *newActionWindowWhen;

    IBOutlet NSButton *startAtLoginStatus;
	IBOutlet NSTextView *logBufferView;
	NSNumber *logBufferPaused;
	NSTimer *logBufferTimer;
    NSMenuItem *donateToControlPlane;
}

- (IBAction)runPreferences:(id)sender;
- (IBAction)runAbout:(id)sender;
- (IBAction)runWebPage:(id)sender;
- (IBAction)emailSupport:(id)sender;
- (IBAction)donateToControlPlane:(id)sender;
- (IBAction)menuBarDisplayOptionChanged:(id)sender;
- (IBAction)enableMultipleActiveContexts:(id)sender;
- (IBAction)closeMultipleActiveContextsAlert:(id)sender;

@property (nonatomic,assign) IBOutlet NSWindow *multipleActiveContextsNotification;

- (void)switchToViewFromToolbar:(NSToolbarItem *)item;
- (void)switchToView:(NSString *)identifier;

// NSToolbar delegates
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)groupId willBeInsertedIntoToolbar:(BOOL)flag;
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar;
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar;
- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar;

- (void)addRule:(id)sender;
- (IBAction)editRule:(id)sender;

- (void)addAction:(id)sender;
- (IBAction)doAddAction:(id)sender;

// Login item stuff
- (NSURL *)appPath;
- (BOOL)willStartAtLogin:(NSURL *)appPath;
- (void)startAtLogin;
- (void)disableStartAtLogin;
- (IBAction)toggleStartAtLoginAction:(id)sender;

@end
