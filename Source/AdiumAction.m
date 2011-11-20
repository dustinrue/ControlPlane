//
//  AdiumAction.m
//  ControlPlane
//
//  Created by Dustin Rue on 11/16/11.
//  Copyright (c) 2011. All rights reserved.
//

#import "AdiumAction.h"
#import <ScriptingBridge/SBApplication.h>
#import "Adium.h"
#import "DSLogger.h"

@implementation AdiumAction

- (id)init
{
	if (!(self = [super init]))
		return nil;
    
	status = [[NSString alloc] init];
    
	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	if (!(self = [super initWithDictionary:dict]))
		return nil;
    
	status = [[dict valueForKey:@"parameter"] copy];
    
	return self;
}

- (void)dealloc
{
	[status release];
    
	[super dealloc];
}

- (NSMutableDictionary *)dictionary
{
	NSMutableDictionary *dict = [super dictionary];
    
	[dict setObject:[[status copy] autorelease] forKey:@"parameter"];
    
	return dict;
}

- (NSString *)description
{
	return [NSString stringWithFormat:NSLocalizedString(@"Setting Adium status to '%@'.", @""), status];
}

- (BOOL) execute: (NSString **) errorString {
    // inspiration comes from:
    // http://stackoverflow.com/questions/4416335/applescript-is-cool-can-i-do-the-same-thing-in-plain-objective-c
	@try {
        
		AdiumApplication *adium = [SBApplication applicationWithBundleIdentifier: @"com.adiumX.adiumX"];
        
        // no sense in changing Adium if it isn't running
        if (![adium isRunning])
            return YES;
		
        AdiumStatus *newStatus = [[[adium classForScriptingClass:@"status"] alloc] init];

        // not entirely sure how this part works, but you basically need
        // to add the newStatus scripting class to the SBApplication/AdiumApplication
        // object in order for it to become useable 
        [[adium statuses] addObject:newStatus];

        [newStatus setSaved:NO];
        [newStatus setTitle:status];
        
        [newStatus setStatusMessage:(AdiumRichText *)status];


        
        [adium setGlobalStatus:newStatus];
		
	} @catch (NSException *e) {
		*errorString = NSLocalizedString(@"Couldn't set Adium status!", @"In AdiumAction");
        DSLog(@"error was %@", e);
		return NO;
	}
	
	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for Adium actions is the status message to set.", @"");
}

+ (NSString *)creationHelpText
{
	return NSLocalizedString(@"Set Adium status message to", @"");
}

@end
