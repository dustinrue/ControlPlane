//
//	WLANSource.h
//	ControlPlane
//
//	Created by David Jennes on 22/09/11.
//	Copyright 2011. All rights reserved.
//

#import "LoopingSource.h"

@interface WLANSource : LoopingSource {
	NSArray *m_networks;
}

@property (readwrite, copy) NSArray *networks;

@end
