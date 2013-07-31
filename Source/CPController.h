//
//  CPController.h
//  ControlPlane
//
//  Created by David Symonds on 1/02/07.
//  Major rework by Vladimir Beloborodov (VladimirTechMan) in April-May 2013.
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
    NSColor *currentColorOfIcon;

	IBOutlet NSMenuItem *forceContextMenuItem;
	BOOL forcedContextIsSticky;
	NSMenuItem *stickForcedContextMenuItem;

	NSLock *updatingSwitchingLock;
	BOOL timeToDie;

	IBOutlet ContextsDataSource *contextsDataSource;
	IBOutlet EvidenceSourceSetController *evidenceSources;
	IBOutlet NSWindow *prefsWindow;
    
    BOOL screenSaverRunning;
    BOOL screenLocked;
    
    BOOL goingToSleep;    
}

@property (readwrite) BOOL screenSaverRunning;
@property (readwrite) BOOL screenLocked;
@property (readwrite) BOOL goingToSleep;
@property (strong) NSArray *activeContexts;

@property (copy,nonatomic,readwrite) NSArray *activeRules;

- (NSString *) currentContextName;
- (ContextsDataSource *) contextsDataSource;
- (BOOL) stickyContext;

- (void) forceSwitch: (id) sender;
- (void) toggleSticky: (id) sender;

- (void)suspendRegularUpdates;
- (void)resumeRegularUpdates;
- (void)resumeRegularUpdatesWithDelay:(int64_t)nanoseconds;
- (void)forceUpdate;

@end
