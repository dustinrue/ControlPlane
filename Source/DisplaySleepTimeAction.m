//
//  DisplaySleepTime.m
//  ControlPlane
//
//  Created by Dustin Rue on 11/9/11.
//  Copyright (c) 2011. All rights reserved.
//

#import "DisplaySleepTimeAction.h"
#import "Action+HelperTool.h"
#import "DSLogger.h"

@implementation DisplaySleepTimeAction


- (id)init
{
	if (!(self = [super init]))
		return nil;
    
	time = [[NSNumber alloc] initWithInt:0];
    
	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	if (!(self = [super initWithDictionary:dict]))
		return nil;
    
	time = [[dict valueForKey:@"parameter"] copy];
    
	return self;
}

- (void)dealloc
{
	[time release];
    
	[super dealloc];
}

- (NSMutableDictionary *)dictionary
{
	NSMutableDictionary *dict = [super dictionary];
    
	[dict setObject:[[time copy] autorelease] forKey:@"parameter"];
    
	return dict;
}

- (NSString *)description
{
	int t = [time intValue];
    
	if (t == 0)
		return NSLocalizedString(@"Disabling display sleep.", @"");
	else if (t == 1)
		return NSLocalizedString(@"Setting display sleep time to 1 minute.", @"");
	else
		return [NSString stringWithFormat:NSLocalizedString(@"Setting display sleep time to %d minutes.", @""), t];
}

- (BOOL)execute:(NSString **)errorString
{
	NSNumber *n = [NSNumber numberWithInt:[time intValue]];
    
	BOOL success = [self helperToolPerformAction:@kCPHelperToolSetDisplaySleepTimeCommand withParameter:n];
    
	if (success) {

	}
    
	if (!success) {
		*errorString = NSLocalizedString(@"Failed setting display sleep time!", @"");
		return NO;
	}
    
	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for DisplaySleepTime action is the time "
                             "(in minutes) before you want your display to sleep or \"Never\" to disable.", @"");
}

+ (NSString *)creationHelpText
{
	return NSLocalizedString(@"Set display sleep time to", @"");
}

+ (NSArray *)limitedOptions
{
	int opts[] = { 3, 5, 15, 30, 60, 120, 0 };
	int num_opts = sizeof(opts) / sizeof(opts[0]);
	NSMutableArray *arr = [NSMutableArray arrayWithCapacity:num_opts];
    
	int i;
	for (i = 0; i < num_opts; ++i) {
		NSNumber *option = [NSNumber numberWithInt:opts[i]];
		NSString *description;
        
		if (opts[i] == 0)
			description = NSLocalizedString(@"Never", @"Display sleep time");
		else if (opts[i] == 1)
			description = NSLocalizedString(@"1 minute", @"Display sleep time");
		else
			description = [NSString stringWithFormat:NSLocalizedString(@"%d minutes", @"Display sleep time"), opts[i]];
        
		[arr addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                        option, @"option",
                        description, @"description", nil]];
	}
    
	return arr;
}

- (id)initWithOption:(NSString *)option
{
	if (!(self = [super init]))
		return nil;
    
	[time autorelease];
	time = [[NSNumber alloc] initWithInt:[option intValue]];
    
	return self;
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Display Sleep Time", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"System Preferences", @"");
}
@end
