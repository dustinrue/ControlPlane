//
//  MPController.h
//  ControlPlane
//
//  Created by David Symonds on 1/02/07.
//

#import <Growl/GrowlApplicationBridge.h>
#import "ContextsDataSource.h"
#import "EvidenceSource.h"


@interface MPController : NSObject <GrowlApplicationBridgeDelegate> {

	IBOutlet NSMenu *sbMenu;
	NSStatusItem *sbItem;
	NSImage *sbImageActive, *sbImageInactive;
	NSTimer *sbHideTimer;

	NSString *currentContextUUID, *currentContextName;
	NSString *guessConfidence;
	BOOL guessIsConfident;
	int smoothCounter;

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
	
	io_connect_t root_port;
	int32_t actionsInProgress;
}

- (NSString *) currentContextName;
- (ContextsDataSource *) contextsDataSource;
- (BOOL) stickyContext;

- (void) forceSwitch: (id) sender;
- (void) toggleSticky: (id) sender;

@end
