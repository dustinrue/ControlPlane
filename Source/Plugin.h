//
//  Plugin.h
//  ControlPlane
//
//  Created by David Jennes on 05/10/11.
//  Copyright 2011. All rights reserved.
//

@protocol Plugin <NSObject>

+ (BOOL) initPlugin: (NSBundle *) bundle;
+ (id<Plugin>) createPlugin: (NSBundle *) bundle;
+ (void) stopPlugin;

@property (readonly) NSString *name;
@property (readonly) NSString *identifier;
@property (readonly) NSString *info;
@property (readonly) NSUInteger version;
@property (readonly) NSUInteger apiVersion;

@property (readonly) NSArray *actions;
@property (readonly) NSArray *rules;
@property (readonly) NSArray *sources;
@property (readonly) NSArray *views;

@end

@interface Plugin : NSObject<Plugin> {
	NSBundle *m_bundle;
}

- (id) initWithBundle: (NSBundle *) bundle;
- (void) registerTypesWithManagers;
- (void) unregisterTypesWithManagers;

@property (readonly) NSBundle *bundle;

@end
