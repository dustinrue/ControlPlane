/* PrefsWindowController */

#import <Cocoa/Cocoa.h>
#import "ContextsDataSource.h"
#import "ContextSelectionButton.h"
#import "MPController.h"

@interface PrefsWindowController : NSWindowController
{
	IBOutlet NSWindow *prefsWindow;
	IBOutlet NSView *generalPrefsView, *contextsPrefsView, *evidenceSourcesPrefsView,
			*rulesPrefsView, *actionsPrefsView, *advancedPrefsView;
	NSView *currentPrefsView, *blankPrefsView;
	NSArray *prefsGroups;
	NSToolbar *prefsToolbar;

	IBOutlet NSDrawer *drawer;

	IBOutlet MPController *mpController;
	IBOutlet EvidenceSourceSetController *evidenceSources;
	IBOutlet ContextsDataSource *contextsDataSource;
	IBOutlet NSArrayController *rulesController, *actionsController;
	IBOutlet NSArrayController *whenActionController;

	// Selection controls for rules/actions
	IBOutlet ContextSelectionButton *defaultContextButton;
	IBOutlet ContextSelectionButton *editRuleContextButton, *editActionContextButton;

	// New action creation hooks
	IBOutlet NSWindow *newActionWindow;
	NSString *newActionType, *newActionTypeString;
	NSString *newActionWindowHelpText;
	IBOutlet NSView *newActionWindowParameterView;
	NSView *newActionWindowParameterViewCurrentControl;
	IBOutlet NSArrayController *newActionLimitedOptionsController;
	IBOutlet NSPopUpButton *newActionContext;
	NSString *newActionWindowWhen;
}

- (IBAction)runPreferences:(id)sender;
- (IBAction)runAbout:(id)sender;
- (IBAction)runWebPage:(id)sender;

- (void)switchToViewFromToolbar:(NSToolbarItem *)item;
- (void)switchToView:(NSString *)identifier;
- (void)resizeWindowToSize:(NSSize)size;

// NSToolbar delegates
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)groupId willBeInsertedIntoToolbar:(BOOL)flag;
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar;
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar;
- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar;

- (void)addRule:(id)sender;
- (IBAction)editRule:(id)sender;

- (void)addAction:(id)sender;
- (IBAction)doAddAction:(id)sender;

@end
