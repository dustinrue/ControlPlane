//
//  CorePlugin.m
//  ControlPlane
//
//  Created by David Jennes on 05/10/11.
//  Copyright 2011. All rights reserved.
//

#import "CorePlugin.h"

@implementation CorePlugin

#import "AudioOutputRule.h"
#import "BonjourRule.h"
#import "DisplayBrightnessRule.h"
#import "DisplayStateRule.h"
#import "FireWireRule.h"
#import "IPRule.h"
#import "KeyboardBrightnessRule.h"
#import "LightRule.h"
#import "LocationRule.h"
#import "MonitorRule.h"
#import "NetworkLinkRule.h"
#import "PowerSourceRule.h"
#import "RunningApplicationRule.h"
#import "SystemStateRule.h"
#import "TimeOfDayRule.h"
#import "USBRule.h"
#import "WLANBSSIDRule.h"
#import "WLANSSIDRule.h"

- (NSArray *) rules {
	return [NSArray arrayWithObjects:
			AudioOutputRule.class,
			BonjourRule.class,
			DisplayBrightnessRule.class,
			DisplayStateRule.class,
			FireWireRule.class,
			IPRule.class,
			KeyboardBrightnessRule.class,
			LightRule.class,
			LocationRule.class,
			MonitorRule.class,
			NetworkLinkRule.class,
			PowerSourceRule.class,
			RunningApplicationRule.class,
			SystemStateRule.class,
			TimeOfDayRule.class,
			USBRule.class,
			WLANBSSIDRule.class,
			WLANSSIDRule.class,
			nil];
}

#import "AudioSource.h"
#import "BonjourSource.h"
#import "FireWireSource.h"
#import "LocationSource.h"
#import "MonitorSource.h"
#import "NetworkSource.h"
#import "PowerSource.h"
#import "RunningApplicationSource.h"
#import "SensorsSource.h"
#import "SystemStateSource.h"
#import "USBSource.h"
#import "WLANSource.h"

- (NSArray *) sources {
	return [NSArray arrayWithObjects:
			AudioSource.class,
			BonjourSource.class,
			FireWireSource.class,
			LocationSource.class,
			MonitorSource.class,
			NetworkSource.class,
			PowerSource.class,
			RunningApplicationSource.class,
			SensorsSource.class,
			SystemStateSource.class,
			USBSource.class,
			WLANSource.class,
			nil];
}

@end
