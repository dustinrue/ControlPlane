//
//  CPController.h
//  ControlPlane
//
//  Created by David Symonds on 1/02/07.
//

#import <Growl/Growl.h>
#import "ContextsDataSource.h"
#import "EvidenceSource.h"
#import "Quincy/BWQuincyManager.h"


@interface CPController : NSObject <GrowlApplicationBridgeDelegate,BWQuincyManagerDelegate> {

	IBOutlet NSMenu *sbMenu;
	NSStatusItem *sbItem;
	NSImage *sbImageActive, *sbImageInactive;
	NSTimer *sbHideTimer;

	NSString *currentContextUUID, *currentContextName;
	NSString *guessConfidence;
	BOOL guessIsConfident;
	NSInteger smoothCounter;

	IBOutlet NSMenuItem *forceContextMenuItem;
	BOOL forcedContextIsSticky;
	NSMenuItem *stickForcedContextMenuItem;

	NSTimer *updatingTimer;
	NSThread *updatingThread;
	NSLock *updatingSwitchingLock;
	NSConditionLock *updatingLock;
	BOOL timeToDie;

	IBOutlet ContextsDataSource *contextsDataSource;
	IBOutlet EvidenceSourceSetController *evidenceSources;
	IBOutlet NSArrayController *rulesController;
	IBOutlet NSArrayController *actionsController;
	IBOutlet NSWindow *prefsWindow;
}

- (NSString *) currentContextName;
- (ContextsDataSource *) contextsDataSource;
- (BOOL) stickyContext;

- (void) forceSwitch: (id) sender;
- (void) toggleSticky: (id) sender;

- (void) doUpdateForReal;

@end
