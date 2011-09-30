//
//  MonitorSource.m
//  ControlPlane
//
//  Created by David Jennes on 30/09/11.
//  Copyright 2011. All rights reserved.
//

#import "MonitorSource.h"
#import <IOKit/graphics/IOGraphicsLib.h>

@implementation MonitorSource

registerSourceType(MonitorSource)
@synthesize devices = m_devices;

- (id) init {
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	self.devices = [[NSDictionary new] autorelease];
	
	return self;
}

#pragma mark - Required implementation of 'LoopingSource' class

- (NSArray *) observableKeys {
	return [NSArray arrayWithObject: @"devices"];
}

- (void) checkData {
	NSMutableDictionary *devices = [[NSMutableDictionary new] autorelease];
	CGDirectDisplayID displays[4];
	CGDisplayCount numDisplays = -1;
	NSString *name;
	
	// get list of displays
	CGError err = CGGetOnlineDisplayList(4, displays, &numDisplays);
	ZAssert(err == kCGErrorSuccess, @"CGGetOnlineDisplayList failed!");
	
	// loop through displays
	for (CGDisplayCount i = 0; i < numDisplays; ++i) {
		CGDirectDisplayID display = displays[i];
		
		// get info
		NSDictionary *info = (NSDictionary *) IODisplayCreateInfoDictionary(CGDisplayIOServicePort(display),
															  kIODisplayOnlyPreferredName);
		ZAssert(info, @"Couldn't get info about display with ID 0x%08x!", display);
		
		// Our unique identifier: product ID (built-in LCDs don't have serial numbers)
		NSNumber *serial = [info objectForKey: (NSString *) CFSTR(kDisplayProductID)];
		
		// Get the product name; should be something like "DELL 1907FP", in the current locale
		NSDictionary *nameDict = [info objectForKey: (NSString *) CFSTR(kDisplayProductName)];
		if (nameDict && nameDict.count > 0)
			name = [nameDict.allValues objectAtIndex: 0];
		else
			name = NSLocalizedString(@"(Unnamed Display)", "MonitorSource");
		
		[devices setObject: name forKey: serial];
		[info release];
	}
	
	// store it
	if (![self.devices isEqualToDictionary: devices])
		self.devices = devices;
}

@end
