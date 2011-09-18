//
//  SourcesManager.m
//  ControlPlane
//
//  Created by David Jennes on 18/09/11.
//  Copyright 2011. All rights reserved.
//

#import "SourcesManager.h"

@implementation SourcesManager

- (id) init {
	self = [super init];
	if (!self)
		return nil;
	
	return self;
}

- (void) dealloc {
	
	[super dealloc];
}

+ (SourcesManager*) sourcesManager {
	static SourcesManager *manager = nil;
	
	if (!manager)
		manager = [[SourcesManager alloc] init];
	
	return manager;
}

@end
