//
//  RunningApplicationEvidenceSource.m
//  ControlPlane
//
//  Created by David Symonds on 23/5/07.
//

#import "RunningApplicationEvidenceSource.h"
#import "DSLogger.h"


@implementation RunningApplicationEvidenceSource

- (id)init
{
	if (!(self = [super init]))
		return nil;

	applications = [[NSMutableArray alloc] init];

	return self;
}

- (void)dealloc
{
	[applications release];

	[super dealloc];
}


- (NSString *) description {
    return NSLocalizedString(@"Create rules based on whether or not an application is running.", @"");
}

- (void)doFullUpdate
{
    NSArray *runningApps = [[NSWorkspace sharedWorkspace] runningApplications];

	NSMutableArray *apps = [[NSMutableArray alloc] initWithCapacity:[runningApps count]];

	for (NSRunningApplication *runningApp in runningApps) {
		NSString *identifier = [runningApp bundleIdentifier];
		NSString *name = [runningApp localizedName];
        
        // some programs, like mdworker, don't have a bundleIdentifier
        if ([identifier length] == 0) 
            identifier = [runningApp localizedName];
        
        if ([identifier length] != 0)
            [apps addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                             identifier, @"identifier", name, @"name", nil]];
	}

	@synchronized(self) {
        [applications setArray:apps];
        [self setDataCollected:[applications count] > 0];
        //[[NSNotificationCenter defaultCenter] postNotificationName:@"evidenceSourceDataDidChange" object:nil];
    #ifdef DEBUG_MODE
        DSLog(@"Running apps:\n%@", applications);
    #endif
    }
	
	[apps release];
}

- (void)start {
	if (running) {
		return;
    }

	/* register for notifications
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(doFullUpdate)
                                                               name:NSWorkspaceDidLaunchApplicationNotification
                                                             object:nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(doFullUpdate)
                                                               name:NSWorkspaceDidTerminateApplicationNotification
                                                             object:nil];
     */
    
    [[NSWorkspace sharedWorkspace] addObserver:self forKeyPath:@"runningApplications" options:NSKeyValueObservingOptionNew context:nil];

    /*
     The system does not post this notification for background apps or for apps that have the LSUIElement key in their Info.plist file. If you want to know when all apps (including background apps) are launched or terminated, use key-value observing to monitor the value returned by the runningApplications method.
     */
	[self doFullUpdate];

	running = YES;
}

- (void)stop {
	if (!running) {
		return;
    }

	// remove notifications
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self
                                                                  name:NSWorkspaceDidLaunchApplicationNotification
                                                                object:nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self
                                                                  name:NSWorkspaceDidTerminateApplicationNotification
                                                                object:nil];

    @synchronized (self) {
        [applications removeAllObjects];
        [self setDataCollected:NO];
    }
	running = NO;
}

- (NSString *)name
{
	return @"RunningApplication";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule
{
	NSString *param = [rule valueForKey:@"parameter"];
	BOOL match = NO;

    @synchronized (self) {
        NSEnumerator *en = [applications objectEnumerator];
        NSDictionary *dict;
        while ((dict = [en nextObject])) {
            if ([[dict valueForKey:@"identifier"] isEqualToString:param]) {
                match = YES;
                break;
            }
        }
    }
	return match;
}

- (NSString *)getSuggestionLeadText:(NSString *)type
{
	return NSLocalizedString(@"The following application running", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions
{
    NSMutableArray *array;
    @synchronized (self) {
        array = [NSMutableArray arrayWithCapacity:[applications count]];
        
        NSEnumerator *en = [applications objectEnumerator];
        NSDictionary *dict;
        while ((dict = [en nextObject])) {
            NSString *identifier = [dict valueForKey:@"identifier"];
            NSString *desc = [NSString stringWithFormat:@"%@ (%@)", [dict valueForKey:@"name"], identifier];
            [array addObject:
             [NSDictionary dictionaryWithObjectsAndKeys:
              @"RunningApplication", @"type",
              identifier, @"parameter",
              desc, @"description", nil]];
        }
    }
	return array;
}

- (NSString *) friendlyName {
    return NSLocalizedString(@"Running Application", @"");
}

-(void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    [self doFullUpdate];
    return;
}

@end
