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
}

+ (SourcesManager *) sharedSourcesManager;
- (void) registerSourceType: (Class) type;
- (void) unregisterSourceType: (Class) type;
- (Source *) getSource: (NSString *) name;

- (Source *) registerRule: (Rule *) rule toSource: (NSString *) source;
- (void) unregisterRule: (Rule *) rule fromSource: (NSString *) source;

@end
