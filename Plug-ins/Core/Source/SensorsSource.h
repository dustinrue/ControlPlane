//
//  SensorsSource.h
//  ControlPlane
//
//  Created by David Jennes on 29/09/11.
//  Copyright 2011. All rights reserved.
//

#import <Plugins/Sources.h>

@interface SensorsSource : LoopingSource<LoopingSourceProtocol> {
	double m_displayBrightness;
	double m_keyboardBrightness;
	double m_lightLevel;
	
	io_connect_t m_dataPort;
}

@property (readwrite, assign) double displayBrightness;
@property (readwrite, assign) double keyboardBrightness;
@property (readwrite, assign) double lightLevel;

@end
