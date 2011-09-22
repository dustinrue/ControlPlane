//
//	PowerSource.m
//	ControlPlane
//
//	Created by David Jennes on 21/09/11.
//	Copyright 2011. All rights reserved.
//

#import "PowerSource.h"
#import "Rule.h"
#import "SourcesManager.h"
#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>

static void sourceChange(void *info);

@implementation PowerSource

@synthesize status = m_status;

- (id) init {
	self = [super init];
	if (!self)
		return nil;
	
	self.status = nil;
	m_runLoopSource = nil;
	
	return self;
}

#pragma mark - Required implementation of 'Source' class

+ (void) load {
	[[SourcesManager sharedSourcesManager] registerSourceType: self];
}

- (NSString *) name {
	return @"Power";
}

- (void) addObserver: (Rule *) rule {
	[self addObserver: rule forKeyPath: @"status" options: NSKeyValueObservingOptionNew context: nil];
}

- (void) removeObserver: (Rule *) rule {
	[self removeObserver: rule forKeyPath: @"status"];
}

#pragma mark - CoreAudio stuff

- (void) registerCallback {
	// register
	m_runLoopSource = IOPSNotificationCreateRunLoopSource(sourceChange, self);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), m_runLoopSource, kCFRunLoopDefaultMode);
}

- (void) unregisterCallback {
	// Unregister listener
	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), m_runLoopSource, kCFRunLoopDefaultMode);
	CFRelease(m_runLoopSource);
	
	self.status = nil;
}

- (void) checkData {
	BOOL onBattery = YES;
	CFTypeRef source;
	
	// get list of power sources
	CFTypeRef blob = IOPSCopyPowerSourcesInfo();
	NSArray *list = [(NSArray *) IOPSCopyPowerSourcesList(blob) autorelease];
	
	// loop through list
	NSEnumerator *en = [list objectEnumerator];
	while ((source = [en nextObject])) {
		NSDictionary *dict = (NSDictionary *) IOPSGetPowerSourceDescription(blob, source);
		
		if ([[dict valueForKey: @kIOPSPowerSourceStateKey] isEqualToString: @kIOPSACPowerValue])
			onBattery = NO;
	}
	CFRelease(blob);
	
	// store it
	self.status = (onBattery ? @"Battery" : @"A/C");
}

static void sourceChange(void *info) {
	PowerSource *src = (PowerSource *) info;
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[src checkData];
	[pool release];
}

@end
