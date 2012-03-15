//
//	DefaultBrowserAction.m
//	ControlPlane
//
//	Created by David Jennes on 03/09/11.
//	Copyright 2011. All rights reserved.
//

#import "DefaultBrowserAction.h"

@interface DefaultBrowserAction (Private)

+ (id) idToName: (NSString *) bundleID;

@end

@implementation DefaultBrowserAction

- (id) init {
	self = [super init];
	if (!self)
		return nil;
	
	app = [[NSString alloc] init];
	
	return self;
}

- (id) initWithDictionary: (NSDictionary *) dict {
	self = [super initWithDictionary: dict];
	if (!self)
		return nil;
	
	app = [[dict valueForKey: @"parameter"] copy];
	
	return self;
}

- (id) initWithOption: (NSString *) option {
	self = [super init];
	if (!self)
		return nil;
	
	app = [option copy];
	
	return self;
}

- (void) dealloc {
	[app release];
	[super dealloc];
}

- (NSMutableDictionary *) dictionary {
	NSMutableDictionary *dict = [super dictionary];
	
	[dict setObject: [[app copy] autorelease] forKey: @"parameter"];
	
	return dict;
}

- (NSString *) description {
	return [NSString stringWithFormat: NSLocalizedString(@"Setting default browser to %@", @""), app];
}

- (BOOL) execute: (NSString **) errorString {
	OSStatus httpResult = LSSetDefaultHandlerForURLScheme((CFStringRef) @"http", (CFStringRef) app);
	OSStatus httpsResult = LSSetDefaultHandlerForURLScheme((CFStringRef) @"https", (CFStringRef) app);
	OSStatus htmlResult = LSSetDefaultRoleHandlerForContentType(kUTTypeHTML, kLSRolesViewer, (CFStringRef) app);
	OSStatus urlResult = LSSetDefaultRoleHandlerForContentType(kUTTypeURL, kLSRolesViewer, (CFStringRef) app);
	
	if (httpResult || httpsResult || htmlResult || urlResult) {
		*errorString = NSLocalizedString(@"Couldn't set default browser '%@'!", @"In DefaultBrowserAction");
		return NO;
	} else
		return YES;
}

+ (NSString *) helpText {
	return NSLocalizedString(@"The parameter for DefaultBrowser actions is the ID (bundle) "
							 "of the new default browser.", @"");
}

+ (NSString *) creationHelpText {
	return NSLocalizedString(@"Set default browser to:", @"");
}

+ (NSArray *) limitedOptions {
	NSArray *handlers = [(NSArray *) LSCopyAllHandlersForURLScheme((CFStringRef) @"http") autorelease];
	
	// no handlers
	if (!handlers)
		return [NSArray array];
	
	NSUInteger total = [handlers count];
	NSMutableArray *options = [NSMutableArray arrayWithCapacity: total];
	
	for (NSUInteger i = 0; i < total; ++i) {
		NSString *bundleID = [handlers objectAtIndex: i];
		
		[options addObject: [NSDictionary dictionaryWithObjectsAndKeys:
							 bundleID, @"option",
							 [self idToName: bundleID], @"description", nil]];
	}
	
	return options;
}

+ (NSString *) idToName: (NSString *) bundleID {
	NSString * path = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier: bundleID];
	
	return [[NSFileManager defaultManager] displayNameAtPath: path];
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Default Browser", @"");
}

@end
