//
//  SourcesManager.h
//  ControlPlane
//
//  Created by David Jennes on 18/09/11.
//  Copyright 2011. All rights reserved.
//

@class Rule;
@class Source;

@interface SourcesManager : NSObject {
	NSMutableDictionary *m_sources;
	NSMutableArray *m_sourceTypes;
	BOOL m_sourcesCreated;
}

+ (SourcesManager *) sharedSourcesManager;
- (void) registerSourceType: (Class) type;
- (Source *) getSource: (NSString *) name;
- (void) removeSource: (Source *) source;

- (Source *) registerRule: (Rule *) rule toSource: (NSString *) source;
- (void) unRegisterRule: (Rule *) rule fromSource: (NSString *) source;

@end
