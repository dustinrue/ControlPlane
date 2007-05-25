//
//  MPController.h
//  MarcoPolo
//
//  Created by David Symonds on 1/02/07.
//

#include "Growl/GrowlApplicationBridge.h"
#import <Cocoa/Cocoa.h>
#import "EvidenceSource.h"


@interface MPController : NSObject <GrowlApplicationBridgeDelegate> {
	IBOutlet NSMenu *sbMenu;
	NSStatusItem *sbItem;
	NSImage *sbImage;
	NSTimer *sbHideTimer;

	NSString *guessedLocation, *guessedConfidence;

	IBOutlet NSMenuItem *forceLocationMenuItem;

	NSThread *updatingThread;
	NSConditionLock *updatingLock;
	BOOL timeToDie;

	IBOutlet EvidenceSourceSetController *evidenceSources;

	IBOutlet NSArrayController *rulesController;
	IBOutlet NSArrayController *actionsController;
}

- (void)showInStatusBar:(id)sender;
- (void)hideFromStatusBar:(NSTimer *)theTimer;

- (IBAction)doUpdate:(NSTimer *)theTimer;

- (unsigned int)pushSuggestionsFromSource:(NSString *)name ofType:(NSString *)type intoController:(NSArrayController *)controller;

// INTERNAL USE:
- (void)updateThread:(id)arg;

- (NSDictionary *)registrationDictionaryForGrowl;
- (NSString *)applicationNameForGrowl;

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag;

@end
