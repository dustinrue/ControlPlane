//
//  ScriptSource.m
//  ControlPlane
//
//  Created by David Jennes on 10/12/11.
//  Copyright 2011. All rights reserved.
//

#import "ScriptRule.h"
#import "ScriptSource.h"
#import <Plugins/NSString+ShellScriptHelper.h>
#import <Plugins/NSTimer+Invalidation.h>

@implementation ScriptSource

@synthesize results = m_results;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	if (!self) return nil;
	
	m_scriptTimers = [NSMutableDictionary new];
	
	return self;
}

- (void) executeScript: (ScriptRule *) rule {
	NSArray *arguments;
	NSString *scriptPath = [rule.script objectAtIndex: 1];
    NSString *interpreter = [scriptPath findInterpreterWithArguments: rule.script intoArguments: &arguments];
	
    // ensure that the discovered interpreter is valid and executable
    if ([interpreter isEqualToString: @""] || ![NSFileManager.defaultManager isExecutableFileAtPath: interpreter]) {
        LogError_Source(@"Failed to execute '%@' because ControlPlane cannot determine how to do so.  Please use '#!/bin/bash' or similar in the script or rename the script with a file extension", scriptPath);
		return;
    }
	
	// create task
	NSTask *task = [NSTask new];
	[task setLaunchPath: interpreter];
	[task setArguments: arguments];
	[task setCurrentDirectoryPath:NSHomeDirectory()];
	
	// set error, input and output to dev null or NSTask will never notice that the script has ended.
	NSFileHandle *devnull = [NSFileHandle fileHandleForWritingAtPath: @"/dev/null"];
	[task setStandardError: devnull];
	[task setStandardInput: devnull];
	[task setStandardOutput: devnull];
	
	// launch task
	[task launch];
	[task waitUntilExit];
	
	// store result
	NSMutableDictionary *newResult = self.results.mutableCopy;
	[newResult setObject: [NSNumber numberWithInt: task.terminationStatus] forKey: rule];
	self.results = newResult;
}

#pragma mark - Required implementation of 'Source' class

- (NSArray *) observableKeys {
	return [NSArray arrayWithObject: @"results"];
}

- (void) start {
	if (self.running)
		return;
	
	self.running = YES;
}

- (void) stop {
	if (!self.running)
		return;
	
	self.running = NO;
}

#pragma mark - 'Source' class overrides

- (void) addObserver: (Rule *) rule {
	[super addObserver: rule];
	
	// start script timer
	ScriptRule *scriptRule = (ScriptRule *) rule;
	NSTimer *temp = [NSTimer scheduledTimerWithTimeInterval: scriptRule.delay
													 target: self
												   selector: @selector(executeScript:)
												   userInfo: scriptRule
													repeats: YES];
	
	// store it for later
	[m_scriptTimers setObject: temp forKey: rule];
}

- (void) removeObserver: (Rule *) rule {
	// remove script timer
	[[m_scriptTimers objectForKey: rule] checkAndInvalidate];
	[m_scriptTimers removeObjectForKey: rule];
	
	[super removeObserver: rule];
}

@end
