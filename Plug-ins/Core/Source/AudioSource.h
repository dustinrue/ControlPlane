//
//	AudioSource.h
//	ControlPlane
//
//	Created by David Jennes on 21/09/11.
//	Copyright 2011. All rights reserved.
//

#import <Plugins/Sources.h>

@interface AudioSource : CallbackSource<CallbackSourceProtocol> {
	NSDictionary *m_devices;
	NSNumber *m_input;
	NSNumber *m_output;
}

@property (readwrite, copy) NSDictionary *devices;
@property (readwrite, copy) NSNumber *input;
@property (readwrite, copy) NSNumber *output;

@end
