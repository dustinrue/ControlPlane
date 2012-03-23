//
//	OpenURLAction.m
//	ControlPlane
//
//	Created by David Jennes on 02/09/11.
//	Copyright 2011. All rights reserved.
//

#import "OpenURLAction.h"


@implementation OpenURLAction

- (id) init {
	self = [super init];
	if (!self)
		return nil;
	
	url = [[NSString alloc] init];
	
	return self;
}

- (id) initWithDictionary: (NSDictionary *) dict {
	self = [super initWithDictionary: dict];
	if (!self)
		return nil;
	
	url = [[dict valueForKey: @"parameter"] copy];
	
	return self;
}

- (void) dealloc {
	[url release];
	
	[super dealloc];
}

- (NSMutableDictionary *) dictionary {
	NSMutableDictionary *dict = [super dictionary];
	
	[dict setObject:[[url copy] autorelease] forKey: @"parameter"];
	
	return dict;
}

- (NSString *) description {
	return [NSString stringWithFormat: NSLocalizedString(@"Open URL '%@'.", @""), url];
}

- (BOOL) execute: (NSString **) errorString {
	if ([[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: url]])
		return YES;
	
	*errorString = [NSString stringWithFormat: NSLocalizedString(@"Failed opening URL '%@'.", @""), url];
	return NO;
}

+ (NSString *) helpText {
	return NSLocalizedString(@"The parameter for the Open URL action is the URL of the page to be opened.", @"");
}

+ (NSString *) creationHelpText {
	return NSLocalizedString(@"Open URL (in a browser)", @"");
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Open URL", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"Web", @"");
}
@end
