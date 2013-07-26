//
//  ActiveApplicationEvidenceSource.m
//  ControlPlane
//
//  Created by Dustin Rue on 8/13/12.
//
//

#import "ActiveApplicationEvidenceSource.h"
#import "DSLogger.h"


@implementation ActiveApplicationEvidenceSource

@synthesize activeApplication;

- (id)init
{
	if (!(self = [super init]))
		return nil;
    
    activeApplication = nil;
    
	return self;
}

- (void)dealloc
{
    
	//[super dealloc];
}


- (NSString *) description {
    return NSLocalizedString(@"Allows you to define rules based on the active or foreground application.", @"");
}
- (void)doFullUpdate:(NSNotification *) notification {
    
    @synchronized(self) {
        [self setActiveApplication:[[[notification userInfo] objectForKey:@"NSWorkspaceApplicationKey"] bundleIdentifier]];
        
        // doFullUpdate is required, so just call it here
        [self doFullUpdate];
    }
 
    [[NSNotificationCenter defaultCenter] postNotificationName:@"evidenceSourceDataDidChange" object:nil];
}

- (void)doFullUpdate {
    
#if DEBUG_MODE
    DSLog(@"active application %@", activeApplication);
#endif
    
	[self setDataCollected:YES];
	
}

- (void)start {
	if (running) {
		return;
    }
    
	// register for notifications
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(doFullUpdate:)
                                                               name:NSWorkspaceDidActivateApplicationNotification
                                                             object:nil];
    
	running = YES;
}

- (void)stop {
	if (!running) {
		return;
    }

	// remove notifications
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self
                                                                  name:NSWorkspaceDidActivateApplicationNotification
                                                                object:nil];
    
	[self setDataCollected:NO];
    
	running = NO;
}

- (NSString *)name
{
	return @"ActiveApplication";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule
{
    BOOL match = NO;
    @synchronized(self) {
        NSString *param = [rule valueForKey:@"parameter"];
        match = NO;
       
        if ([[self activeApplication] isEqualToString:param]) {
            match = YES;
        }
    }
	return match;
}

- (NSString *)getSuggestionLeadText:(NSString *)type
{
	return NSLocalizedString(@"The following application is active", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions
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
    
	[lock lock];
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:[apps count]];
    
	NSEnumerator *en = [apps objectEnumerator];
	NSDictionary *dict;
	while ((dict = [en nextObject])) {
		NSString *identifier = [dict valueForKey:@"identifier"];
		NSString *desc = [NSString stringWithFormat:@"%@ (%@)", [dict valueForKey:@"name"], identifier];
		[array addObject:
         [NSDictionary dictionaryWithObjectsAndKeys:
          @"ActiveApplication", @"type",
          identifier, @"parameter",
          desc, @"description", nil]];
	}
    //[apps release];
	[lock unlock];
    
	return array;
}

- (NSString *) friendlyName {
    return NSLocalizedString(@"Active Application", @"");
}

- (void) goingToSleep:(id)arg {
    if (running)
        activeApplication = nil;
}

@end
