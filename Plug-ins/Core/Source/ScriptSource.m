//
//  ScriptSource.m
//  ControlPlane
//
//  Created by David Jennes on 10/12/11.
//  Copyright 2011. All rights reserved.
//

#import "ScriptRule.h"
#import "ScriptSource.h"

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
	// launch script
	NSTask *task = [NSTask launchedTaskWithLaunchPath: @"/bin/sh" arguments: rule.script];
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
	[[m_scriptTimers objectForKey: rule] invalidate];
	[m_scriptTimers removeObjectForKey: rule];
	
	[super removeObserver: rule];
}

@end
