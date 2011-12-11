//
//  ScriptRule.m
//  ControlPlane
//
//  Created by David Jennes on 10/12/11.
//  Copyright 2011. All rights reserved.
//

#import "ScriptRule.h"
#import "ScriptSource.h"

@implementation ScriptRule

@synthesize delay = m_delay;
@synthesize script = m_script;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	if (!self) return nil;
	
	m_result = nil;
	
	return self;
}

#pragma mark - Source observe functions

- (void) resultsChangedWithOld: (NSDictionary *) oldResults andNew: (NSDictionary *) newResults {
	self.match = [[newResults objectForKey: self] isEqualToNumber: m_result];
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"Script", @"Rule type");
}

- (NSString *) category {
	return NSLocalizedString(@"Other", @"Rule category");
}

- (NSString *) helpText {
	return NSLocalizedString(@"Script result is", @"ScriptRule");
}

- (void) beingEnabled {
	Source *source = [SourcesManager.sharedSourcesManager registerRule: self toSource: @"ScriptSource"];
	
	// currently a match?
	[self resultsChangedWithOld: nil andNew: ((ScriptSource *) source).results];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unregisterRule: self fromSource: @"ScriptSource"];
}

- (void) loadData: (id) data {
	m_delay = [[data objectForKey: @"delay"] doubleValue];
	m_script = [data objectForKey: @"script"];
	m_result = [data objectForKey: @"result"];
}

- (NSString *) describeValue: (id) value {
	NSString *scriptPath = [[value objectForKey: @"script"] objectAtIndex: 0];
	
	return scriptPath.lastPathComponent.stringByDeletingPathExtension;
}

- (NSArray *) suggestedValues {
	NSArray *script = [NSArray arrayWithObject:
					   [NSString stringWithFormat: @"%@myScript.sh", NSHomeDirectory()]];
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
			script, @"script",
			[NSNumber numberWithDouble: 10.0], @"delay",
			[NSNumber numberWithInt: 0], @"result",
			nil];
}

@end
