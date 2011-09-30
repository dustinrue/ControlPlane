//
//  MonitorSource.h
//  ControlPlane
//
//  Created by David Jennes on 30/09/11.
//  Copyright 2011. All rights reserved.
//

#import "LoopingSource.h"

@interface MonitorSource : LoopingSource {
	NSDictionary *m_devices;
}

@property (readwrite, copy) NSDictionary *devices;

@end
