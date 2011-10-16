//
//	RunningApplicationRule.m
//	ControlPlane
//
//	Created by David Jennes on 24/09/11.
//	Copyright 2011. All rights reserved.
//

#import "RunningApplicationRule.h"
#import "RunningApplicationSource.h"

@implementation RunningApplicationRule

#pragma mark - Source observe functions

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_identifier = nil;
	
	return self;
}

- (void) applicationsChangedWithOld: (NSDictionary *) oldList andNew: (NSDictionary *) newList {
	self.match = ([newList valueForKey: m_identifier] != nil);
}

#pragma mark - Required implementation of 'Rule' class

- (NSString *) name {
	return NSLocalizedString(@"Running Application", @"Rule type");
}

- (NSString *) category {
	return NSLocalizedString(@"System", @"Rule category");
}

- (NSString *) helpText {
	return NSLocalizedString(@"The following application is running", @"RunningApplicationRule");
}

- (void) beingEnabled {
	Source *source = [SourcesManager.sharedSourcesManager registerRule: self toSource: @"RunningApplicationSource"];
	
	// currently a match?
	[self applicationsChangedWithOld: nil andNew: ((RunningApplicationSource *) source).applications];
}

- (void) beingDisabled {
	[SourcesManager.sharedSourcesManager unregisterRule: self fromSource: @"RunningApplicationSource"];
}

- (void) loadData: (id) data {
	m_identifier = data;
}

- (NSString *) describeValue: (id) value {
	RunningApplicationSource *source = (RunningApplicationSource *) [SourcesManager.sharedSourcesManager getSource: @"RunningApplicationSource"];
	NSString *name = [source.applications objectForKey: value];
	
	if (!name)
		name = NSLocalizedString(@"Unknown Application", @"RunningApplicationRule value description");
	
	return name;
}

- (NSArray *) suggestedValues {
	RunningApplicationSource *source = (RunningApplicationSource *) [SourcesManager.sharedSourcesManager getSource: @"RunningApplicationSource"];
	
	return source.applications.allKeys;
}

@end
