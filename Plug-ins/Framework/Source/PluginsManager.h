//
//  PluginsManager.h
//  ControlPlane
//
//  Created by David Jennes on 05/10/11.
//  Copyright 2011. All rights reserved.
//

@class Plugin;

@interface PluginsManager : NSObject {
	NSMutableDictionary *m_plugins;
}

+ (PluginsManager *) sharedPluginsManager;
- (Plugin *) pluginWithIdentifier: (NSString *) identifier;

- (void) loadPlugin: (NSString *) path;
- (void) unloadPlugin: (Plugin *) plugin;

- (void) loadPlugins;
- (void) unloadPlugins;

@end
