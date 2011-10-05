//
//  PluginsManager.m
//  ControlPlane
//
//  Created by David Jennes on 05/10/11.
//  Copyright 2011. All rights reserved.
//

#import "PluginsInternal.h"
#import "Plugin.h"
#import "PluginsManager.h"
#import "SynthesizeSingleton.h"

@implementation PluginsManager

SYNTHESIZE_SINGLETON_FOR_CLASS(PluginsManager);

- (id) init {
	ZAssert(!sharedPluginsManager, @"This is a singleton, use %@.shared%@", NSStringFromClass(self.class), NSStringFromClass(self.class));
	
	self = [super init];
	ZAssert(self, @"Unable to init super '%@'", NSStringFromClass(super.class));
	
	m_plugins = [NSMutableDictionary new];
	
	return self;
}

- (void) dealloc {
	[m_plugins release];
	
	[super release];
}

- (Plugin *) pluginWithIdentifier: (NSString *) identifier {
	return [m_plugins objectForKey: identifier];
}

- (void) loadPlugin: (NSString *) path {
	Class class;
	Plugin *plugin;
	
	// Load bundle
	NSBundle *bundle = [NSBundle bundleWithPath: path];
	ZAssert(bundle, @"No bundle at %@", path);
	ZAssert([bundle load], @"Bundle %@ didn't load", bundle);
	
	// Init plugin
	class = bundle.principalClass;
	ZAssert(class, @"Bundle %@ has no principal class", bundle);
	ZAssert([class conformsToProtocol: @protocol(Plugin)], @"Class %@ doesn't conform to protocol", class);
	ZAssert([class initPlugin: bundle], @"Couldn't init plugin %@", class);
	
	// Create plugin
	@try {
		plugin = [class createPlugin: bundle];
	} @catch (NSException *problem) {
		ALog(@"createPlugin failed");
	}
	ZAssert(plugin, @"Plugin instance is nil");
	ZAssert(plugin.identifier, @"Plugin identifier is nil");
	
	// store it
	[m_plugins setObject: plugin forKey: plugin.identifier];
}

- (void) unloadPlugin: (Plugin *) plugin {
	// Remove from dictionary
	[plugin retain];
	[m_plugins removeObjectForKey: plugin.identifier];
	
	// Stop plugin
	@try {
		[plugin.class stopPlugin];
	} @catch (NSException *warn) {
		ALog(@"stopPlugin failed");
	}
	
	// Delete it
	[plugin release];
}

- (void) loadPlugins {
	static NSString * const appSupportPath = @"Application Support/ControlPlane/PlugIns";
	static NSString * const pluginType = @"plugin";
	NSMutableArray *paths = [[NSMutableArray new] autorelease];
	NSFileManager *fm = [NSFileManager defaultManager];
	
	// Built in path
    NSString *builtInPath = NSBundle.mainBundle.builtInPlugInsPath;
    ZAssert(builtInPath, @"Couldn't get built-in path");
	
	// Library search paths
	NSArray *libraries = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
															 NSUserDomainMask | NSLocalDomainMask,
															 YES);
	
	// find all plugins
	[paths addObjectsFromArray: [NSBundle pathsForResourcesOfType: pluginType
													  inDirectory: builtInPath]];
	for (NSString *path in libraries) {
		path = [path stringByAppendingPathComponent: appSupportPath];
		[paths addObjectsFromArray: [fm contentsOfDirectoryAtPath: path error: nil]];
	}
	
	// load plugins
	for (NSString *plugin in paths)
		[self loadPlugin: plugin];
}

- (void) unloadPlugins {
	for (Plugin *plugin in m_plugins.allValues)
		[self unloadPlugin: plugin];
}

@end
