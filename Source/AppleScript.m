//
//  AppleScript.m
//  ControlPlane
//
//  Created by David Jennes on 24/08/11.
//  Copyright 2011. All rights reserved.
//

#import "AppleScript.h"
#import "CPController.h"

@implementation NSApplication (AppleScript)

// current context property

- (NSString *) currentContext {
	return [(CPController *)[NSApp delegate] currentContextAsString];
}

- (void) setCurrentContext: (NSString*) newContext {
	CPController *c = (CPController *) [NSApp delegate];
	Context *context = [[c contextsDataSource] contextByName: newContext];
	
	if (context)
		[c forceSwitch: context];
	else
		NSLog(@"Context not found: '%@'", newContext);
}

// sticky property

- (NSNumber *) sticky {
	return [NSNumber numberWithBool: [(CPController *)[NSApp delegate] stickyContext]];
}

- (void) setSticky: (NSNumber *) sticky {
	CPController *c = (CPController *) [NSApp delegate];
	
	if ([c stickyContext] != [sticky boolValue])
		[c toggleSticky:nil];
}

@end
