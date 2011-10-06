//
//	WLANSource.h
//	ControlPlane
//
//	Created by David Jennes on 22/09/11.
//	Copyright 2011. All rights reserved.
//

#import <Plugins/Sources.h>

@interface WLANSource : LoopingSource<LoopingSourceProtocol> {
	NSArray *m_networks;
}

@property (readwrite, copy) NSArray *networks;

@end
