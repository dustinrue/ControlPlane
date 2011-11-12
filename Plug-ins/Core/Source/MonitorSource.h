//
//  MonitorSource.h
//  ControlPlane
//
//  Created by David Jennes on 30/09/11.
//  Copyright 2011. All rights reserved.
//

#import <Plugins/Sources.h>

@interface MonitorSource : LoopingSource<LoopingSourceProtocol> {
	NSDictionary *m_devices;
}

@property (readwrite, copy) NSDictionary *devices;

@end
