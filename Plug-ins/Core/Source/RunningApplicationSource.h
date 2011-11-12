//
//	PowerSource.h
//	ControlPlane
//
//	Created by David Jennes on 23/09/11.
//	Copyright 2011. All rights reserved.
//

#import <Plugins/Sources.h>

@interface RunningApplicationSource : CallbackSource<CallbackSourceProtocol> {
	NSDictionary *m_applications;
}

@property (readwrite, copy) NSDictionary *applications;

@end
