//
//	RunningApplicationSource.m
//	ControlPlane
//
//	Created by David Jennes on 23/09/11.
//	Copyright 2011. All rights reserved.
//

#import "RunningApplicationSource.h"

@implementation RunningApplicationSource

registerSource(RunningApplicationSource)
@synthesize runningApplications = m_runningApplications;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	self.runningApplications = [[NSArray new] autorelease];
	
	return self;
}

#pragma mark - Required implementation of 'CallbackSource' class

- (NSArray *) observableKeys {
	return [NSArray arrayWithObject: @"runningApplications"];
}

- (void) registerCallback {
	[NSWorkspace.sharedWorkspace.notificationCenter addObserver: self
													   selector: @selector(checkData)
														   name: NSWorkspaceDidLaunchApplicationNotification
														 object: nil];
	[NSWorkspace.sharedWorkspace.notificationCenter addObserver: self
													   selector: @selector(checkData)
														   name: NSWorkspaceDidTerminateApplicationNotification
														 object: nil];
}

- (void) unregisterCallback {
	[NSWorkspace.sharedWorkspace.notificationCenter removeObserver: self
															  name: nil
															object: nil];
	
	self.runningApplications = [[NSArray new] autorelease];
}

- (void) checkData {
	NSArray *apps = [NSWorkspace.sharedWorkspace runningApplications];
	NSMutableArray *result = [[[NSMutableArray alloc] initWithCapacity: apps.count] autorelease];
	
	// loop through apps and get their info
	for (NSRunningApplication *app in apps)
		[result addObject: [NSDictionary dictionaryWithObjectsAndKeys:
							app.bundleIdentifier, @"identifier",
							app.localizedName, @"name", nil]];
	
	// store it
	self.runningApplications = result;
}

@end
