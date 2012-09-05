//
//  CPController.h
//  ControlPlane
//
//  Created by David Symonds on 1/02/07.
//

#import "ContextsDataSource.h"
#import "EvidenceSource.h"
#import "BWQuincyManager.h"


@interface CPController : NSObject <BWQuincyManagerDelegate> {

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
    NSLock *menuBarLocker;
	NSConditionLock *updatingLock;
	BOOL timeToDie;

	IBOutlet ContextsDataSource *contextsDataSource;
	IBOutlet EvidenceSourceSetController *evidenceSources;
	IBOutlet NSArrayController *rulesController;
	IBOutlet NSArrayController *actionsController;
	IBOutlet NSWindow *prefsWindow;
    
    BOOL screenSaverRunning;
    BOOL screenLocked;
    
    BOOL goingToSleep;
    
    // used to maintain a queue of actions that need
    // to be performed after the screen saver quits AND/OR
    // the screen is unlocked
    NSMutableArray *screensaverActionArrivalQueue;
    NSMutableArray *screensaverActionDepartureQueue;
    NSMutableArray *screenLockActionArrivalQueue;
    NSMutableArray *screenLockActionDepartureQueue;
}

@property (readwrite) BOOL screenSaverRunning;
@property (readwrite) BOOL screenLocked;
@property (readwrite) BOOL goingToSleep;
@property (strong) NSArray *activeContexts;

- (NSString *) currentContextName;
- (ContextsDataSource *) contextsDataSource;
- (BOOL) stickyContext;

- (void) forceSwitch: (id) sender;
- (void) toggleSticky: (id) sender;

- (void) doUpdateForReal;

@end
