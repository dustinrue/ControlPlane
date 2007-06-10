/* PrefsWindowController */

#import <Cocoa/Cocoa.h>
#import "MPController.h"

@interface PrefsWindowController : NSWindowController
{
	IBOutlet NSWindow *prefsWindow;
	IBOutlet NSView *generalPrefsView, *evidenceSourcesPrefsView, *rulesPrefsView, *actionsPrefsView, *advancedPrefsView;
	NSView *currentPrefsView, *blankPrefsView;
	NSArray *prefsGroups;
	NSToolbar *prefsToolbar;

	IBOutlet NSDrawer *drawer;

	IBOutlet MPController *mpController;
	IBOutlet NSArrayController *rulesController, *actionsController;
	IBOutlet NSArrayController *whenActionController;

	// General new stuff hooks
	IBOutlet NSArrayController *newLocationController;

	// New rule creation hooks
	IBOutlet NSWindow *newRuleWindow;
	NSString *newRuleType;
	NSString *newRuleWindowText1;
	IBOutlet NSArrayController *newRuleParameterController;
	IBOutlet NSSlider *newRuleConfidenceSlider;

	// New action creation hooks
	IBOutlet NSWindow *newActionWindow;
	NSString *newActionType, *newActionTypeString;
	NSString *newActionWindowHelpText;
	IBOutlet NSView *newActionWindowParameterView;
	NSView *newActionWindowParameterViewCurrentControl;
	IBOutlet NSArrayController *newActionLimitedOptionsController;
}

- (IBAction)runPreferences:(id)sender;
- (IBAction)runAbout:(id)sender;

- (void)switchToViewFromToolbar:(NSToolbarItem *)item;
- (void)switchToView:(NSString *)identifier;
- (void)resizeWindowToSize:(NSSize)size;

// NSToolbar delegates
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)groupId willBeInsertedIntoToolbar:(BOOL)flag;
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar;
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar;
- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar;

- (void)addRule:(id)sender;
- (IBAction)doAddRule:(id)sender;

- (void)addAction:(id)sender;
- (IBAction)doAddAction:(id)sender;

@end
