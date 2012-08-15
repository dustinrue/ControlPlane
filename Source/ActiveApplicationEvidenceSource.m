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
    
	applications = [[NSMutableArray alloc] init];
    activeApplication = nil;
    
	return self;
}

- (void)dealloc
{
	[applications release];
    
	[super dealloc];
}

- (void)doFullUpdate {
    
    NSDictionary *activeApp = [[NSWorkspace sharedWorkspace] activeApplication];
	
    activeApplication = [activeApp valueForKey:@"NSApplicationBundleIdentifier"];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"evidenceSourceDataDidChange" object:nil];
	
#ifdef DEBUG_MODE
	DSLog(@"Active app:\n%@", [activeApp valueForKey:@"NSApplicationBundleIdentifier"]);
#endif
	
	[self setDataCollected:YES];
	
}

- (void)start
{
	if (running)
		return;
    
	// register for notifications
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(doFullUpdate) name:NSWorkspaceDidActivateApplicationNotification object:nil];
	
    
	[self doFullUpdate];
    
	running = YES;
}

- (void)stop
{
	if (!running)
		return;
    
	// remove notifications
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self
                                                                  name:nil
                                                                object:nil];
    
	[lock lock];
	[applications removeAllObjects];
	[self setDataCollected:NO];
	[lock unlock];
    
	running = NO;
}

- (NSString *)name
{
	return @"ActiveApplication";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule
{
	NSString *param = [rule valueForKey:@"parameter"];
	BOOL match = NO;
    
    [lock lock];
    if (activeApplication != nil && param != nil) {
        if ([activeApplication isEqualToString:param]) {
            match = YES;
        }
    }
    [lock unlock];

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
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:[applications count]];
    
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
    [apps release];
	[lock unlock];
    
	return array;
}

- (NSString *) friendlyName {
    return NSLocalizedString(@"Active Application", @"");
}

@end
