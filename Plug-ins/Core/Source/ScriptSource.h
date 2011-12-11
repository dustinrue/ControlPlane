//
//  ScriptSource.h
//  ControlPlane
//
//  Created by David Jennes on 10/12/11.
//  Copyright 2011. All rights reserved.
//

#import <Plugins/Sources.h>

@interface ScriptSource : Source<SourceProtocol> {
	NSMutableDictionary *m_scriptTimers;
	NSDictionary *m_results;
}

@property (readwrite, copy) NSDictionary *results;

@end
