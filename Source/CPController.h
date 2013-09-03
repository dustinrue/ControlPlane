//
//  CPController.h
//  ControlPlane
//
//  Created by David Symonds on 1/02/07.
//  Major rework by Vladimir Beloborodov (VladimirTechMan) in Q2-Q3 2013.
//

#import "ContextsDataSource.h"
#import "EvidenceSource.h"
#import "BWQuincyManager.h"


@interface CPController : NSObject <BWQuincyManagerDelegate>

@property (retain,atomic,readonly) NSString *currentContextName;
@property (retain,atomic,readonly) NSString *currentContextPath;

@property (readwrite) BOOL screenSaverRunning;
@property (readwrite) BOOL screenLocked;
@property (readwrite) BOOL goingToSleep;
@property (strong) NSArray *activeContexts;

@property (copy,nonatomic,readwrite) NSArray *activeRules;

- (ContextsDataSource *)contextsDataSource;
- (BOOL)stickyContext;

- (void)forceSwitch: (id) sender;
- (void)toggleSticky: (id) sender;

- (void)restartSwitchSmoothing;

- (void)suspendRegularUpdates;
- (void)resumeRegularUpdates;
- (void)resumeRegularUpdatesWithDelay:(int64_t)nanoseconds;
- (void)forceUpdate;

@end
