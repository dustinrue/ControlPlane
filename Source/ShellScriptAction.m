//
//  ShellScriptAction.m
//  ControlPlane
//
//  Created by David Symonds on 23/04/07.
//  Improved by Vladimir Beloborodov (VladimirTechMan) on 20 Aug 2013.
//

#import "CPNotifications.h"
#import "DSLogger.h"
#import "ShellScriptAction.h"
#import "NSString+ShellScriptHelper.h"

@implementation ShellScriptAction

- (id)init {
	if (!(self = [super init]))
		return nil;

	path = [[NSString alloc] init];

	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict {
	if (!(self = [super initWithDictionary:dict]))
		return nil;

	path = [[dict valueForKey:@"parameter"] copy];

	return self;
}

- (void)dealloc {
	[path release];

	[super dealloc];
}

- (NSMutableDictionary *)dictionary {
	NSMutableDictionary *dict = [super dictionary];

	[dict setObject:[[path copy] autorelease] forKey:@"parameter"];

	return dict;
}

- (NSString *)description {
	return [NSString stringWithFormat:NSLocalizedString(@"Running shell script '%@'.", @""), path];
}

- (BOOL)execute:(NSString **)errorString {
    NSString *interpreter = @"";

    // Split on "|", add "--" to the start so that the shell won't try to parse arguments
	NSMutableArray *args = [[[path componentsSeparatedByString:@"|"] mutableCopy] autorelease];
	[args insertObject:@"--" atIndex:0];
	NSString *scriptPath = args[1];

    // ControlPlane is going to attempt to peek inside the script to figure out
	// what interpreter needs to be called
    NSMutableArray *shebangArgs = [scriptPath interpreterFromFile];
	if (shebangArgs && [shebangArgs count] > 0) {
		// get interpreter
		interpreter = shebangArgs[0];
		[shebangArgs removeObjectAtIndex: 0];

		// and it's parameters
		if (shebangArgs.count > 0) {
			[shebangArgs addObjectsFromArray: args];
			args = shebangArgs;
		}
		
	}

    // backup routine to try using the file extension if it exists
    if ([interpreter isEqualToString: @""]) {
		interpreter = [scriptPath interpreterFromExtension];
	}

    // ensure that the discovered interpreter is valid and executable
    if ([interpreter isEqualToString: @""] || ![NSFileManager.defaultManager isExecutableFileAtPath:interpreter]) {
        // can't determine how to run the script
        DSLog(@"Failed to execute '%@' because ControlPlane cannot determine how to do so."
              " Please use '#!/bin/bash' or similar in the script or rename the script with a file extension", path);
        *errorString = NSLocalizedString(@"Unable to determine interpreter for shell script!"
                                         " (see log for details)", @"");
		return NO;
    }

    [self launchTaskWithLaunchPath:interpreter arguments:args];

	return YES;
}

- (void)launchTaskWithLaunchPath:(NSString *)launchPath arguments:(NSArray *)args {
    NSTask *task = [[[NSTask alloc] init] autorelease];
    task.launchPath = launchPath;
    task.arguments = args;
    
    NSString *pathCopy = [[path copy] autorelease];
    task.terminationHandler = ^(NSTask *terminatedTask) {
        if (terminatedTask.terminationReason == NSTaskTerminationReasonUncaughtSignal) {
            DSLog(@"Failed to execute '%@' (script terminated due to an uncaught signal)", pathCopy);
            NSString *title = NSLocalizedString(@"Failure", @"Growl message title");
            NSString *errorMsg = NSLocalizedString(@"Failed executing shell script! (see log for details)", @"");
            [CPNotifications postUserNotification:title withMessage:errorMsg];
            return;
        }

        int terminationStatus = terminatedTask.terminationStatus;
        if (terminationStatus != 0) {
            DSLog(@"Failed to execute '%@' (script terminated with a non-zero status '%d')",
                  pathCopy, terminationStatus);
            NSString *title = NSLocalizedString(@"Failure", @"Growl message title");
            NSString *errorMsg = NSLocalizedString(@"Failed executing shell script! (see log for details)", @"");
            [CPNotifications postUserNotification:title withMessage:errorMsg];
            return;
        }
    };
    
    [task launch];
}

+ (NSString *)helpText {
	return NSLocalizedString(@"The parameter for ShellScript actions is the full path of the"
                             " shell script, which will be executed with /bin/sh.", @"");
}

- (id)initWithFile:(NSString *)file {
	self = [super init];
	[path release];
	path = [file copy];
	return self;
}

+ (NSString *)friendlyName {
    return NSLocalizedString(@"Run Shell Script", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"System", @"");
}

@end
