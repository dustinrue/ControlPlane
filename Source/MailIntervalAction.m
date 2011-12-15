//
//	MailIntervalAction.m
//	ControlPlane
//
//	Created by David Jennes on 02/09/11.
//	Copyright 2011. All rights reserved.
//

#import "MailIntervalAction.h"
#import <ScriptingBridge/SBApplication.h>
#import "Mail.h"
#import "DSLogger.h"

@implementation MailIntervalAction

- (id) init {
	self = [super init];
	if (!self)
		return nil;
	
	time = [[NSNumber alloc] initWithInt: 0];
	
	return self;
}

- (id) initWithDictionary: (NSDictionary *) dict {
	self = [super initWithDictionary: dict];
	if (!self)
		return nil;
	
	time = [[dict valueForKey: @"parameter"] copy];
	
	return self;
}

- (id) initWithOption: (NSString *) option {
	self = [super init];
	if (!self)
		return nil;
	
	time = [[NSNumber alloc] initWithInt: [option intValue]];
	
	return self;
}

- (void) dealloc {
	[time release];
	[super dealloc];
}

- (NSMutableDictionary *) dictionary {
	NSMutableDictionary *dict = [super dictionary];
	
	[dict setObject: [[time copy] autorelease] forKey: @"parameter"];
	
	return dict;
}

- (NSString *) description {
	int t = [time intValue];
	
	if (t == 0)
		return NSLocalizedString(@"Disabling automatic mail checking.", @"");
	else if (t == 1)
		return NSLocalizedString(@"Setting mail checking interval to 1 minute.", @"");
	else
		return [NSString stringWithFormat: NSLocalizedString(@"Setting mail checking interval to %d minutes.", @""), t];
}

- (BOOL) execute: (NSString **) errorString {
	@try {
		MailApplication *Mail = [SBApplication applicationWithBundleIdentifier: @"com.apple.mail"];
		int t = [time intValue];
		
		if (t == 0)
			Mail.fetchesAutomatically = NO;
		else {
			Mail.fetchesAutomatically = YES;
			Mail.fetchInterval = t;
		}
	} @catch (NSException *e) {
		DSLog(@"Exception: %@", e);
		*errorString = NSLocalizedString(@"Couldn't set mail check interval!", @"In MailIntervalAction");
		return NO;
	}
	
	return YES;
}

+ (NSString *) helpText {
	return NSLocalizedString(@"The parameter for MailIntervalAction actions is the time "
							 "(in minutes) between each check for new mails.", @"");
}

+ (NSString *) creationHelpText {
	return NSLocalizedString(@"Set mail check interval to", @"");
}

+ (NSArray *) limitedOptions {
	int options[] = {1, 5, 15, 30, 60, 0};
	int total = sizeof(options) / sizeof(options[0]);
	NSMutableArray *arr = [NSMutableArray arrayWithCapacity: total];
	
	for (int i = 0; i < total; ++i) {
		NSNumber *option = [NSNumber numberWithInt: options[i]];
		NSString *description;
		
		switch (options[i]) {
			case 0:
				description = NSLocalizedString(@"Manually", @"Mail check interval");
				break;
			case 1:
				description = NSLocalizedString(@"Every minute", @"Mail check interval");
				break;
			case 60:
				description = NSLocalizedString(@"Every hour", @"Mail check interval");
				break;
			default:
				description = [NSString stringWithFormat: NSLocalizedString(@"Every %d minutes", @"Mail check interval"), options[i]];
		}
		
		[arr addObject: [NSDictionary dictionaryWithObjectsAndKeys:
						 option, @"option",
						 description, @"description", nil]];
	}
	
	return arr;
}

@end
