//
//  ShellScriptAction.m
//  ControlPlane
//
//  Created by David Symonds on 23/04/07.
//

#import "ShellScriptAction.h"


@implementation ShellScriptAction

- (id)init
{
	if (!(self = [super init]))
		return nil;

	path = [[NSString alloc] init];

	return self;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	if (!(self = [super initWithDictionary:dict]))
		return nil;

	path = [[dict valueForKey:@"parameter"] copy];

	return self;
}

- (void)dealloc
{
	[path release];

	[super dealloc];
}

- (NSMutableDictionary *)dictionary
{
	NSMutableDictionary *dict = [super dictionary];

	[dict setObject:[[path copy] autorelease] forKey:@"parameter"];

	return dict;
}

- (NSString *)description
{
	return [NSString stringWithFormat:NSLocalizedString(@"Running shell script '%@'.", @""), path];
}

- (BOOL)execute:(NSString **)errorString
{
    NSString *app, *fileType;
    
	if (![[NSWorkspace sharedWorkspace] getInfoForFile:path application:&app type:&fileType]) {
		*errorString = [NSString stringWithFormat:NSLocalizedString(@"Failed opening '%@'.", @""), path];
		return NO;
	}
    
    // Split on "|", add "--" to the start so that the shell won't try to parse arguments
	NSMutableArray *args = [[[path componentsSeparatedByString:@"|"] mutableCopy] autorelease];
	[args insertObject:@"--" atIndex:0];
    
    
    // ControlPlane is going to attempt to peek inside the script to figure
    // out what interpreter needs to be called, if that fails
    // it'll attempt to determine the interpreter using the script's extension
    NSError *readFileError;
    
    NSString *fileContents = [NSString stringWithContentsOfFile:[args objectAtIndex:1] encoding:NSUTF8StringEncoding error:&readFileError];

    NSString *interpreter = @"";
    
    // find the interpreter 
    NSRange anNsRange;
    for (NSString *currentLine in [fileContents componentsSeparatedByString:@"\n"]) {
        anNsRange = [currentLine rangeOfString:@"#!"];
        if (anNsRange.location != NSNotFound) {
            
            // next ControlPlane will determine if the shabang line includes
            // any arguments and deals with that appropriately
            NSMutableArray *shaBangArgs = [[[currentLine componentsSeparatedByString:@" "] mutableCopy] autorelease ];
            
            // if shaBangArgs is bigger than 1 then the user
            // must be sending args to the interpreter, deal with 
            // that case here
            if([shaBangArgs count] > 1) {
                interpreter = [shaBangArgs objectAtIndex:0];
                [shaBangArgs removeObjectAtIndex:0];
                [shaBangArgs addObjectsFromArray:args];
                [args removeAllObjects];
                [args addObjectsFromArray:shaBangArgs];
            }
            else {
                interpreter = currentLine;
            }
            
            // strip the leading #!
            interpreter = [interpreter substringFromIndex:2];
           
        }
    }
    
    // backup routine to try using the file extension if it exists
    if ([interpreter isEqualToString:@""]) {
        if ([[fileType uppercaseString] isEqualToString:@"SH"]) {
            interpreter = @"/bin/bash";
        }
        else if ([[fileType uppercaseString] isEqualToString:@"SCPT"]) {
            interpreter = @"/usr/bin/osascript";
        }
        else if ([[fileType uppercaseString] isEqualToString:@"PL"]) {
            interpreter = @"/usr/bin/perl";
        }
        else if ([[fileType uppercaseString] isEqualToString:@"PY"]) {
            interpreter = @"/usr/bin/python";
        }
        else if ([[fileType uppercaseString] isEqualToString:@"PHP"]) {
            interpreter = @"/usr/bin/php";
        }
        else if ([[fileType uppercaseString] isEqualToString:@"EXPECT"]) {
            interpreter = @"/usr/bin/expect";
        }
        else if ([[fileType uppercaseString] isEqualToString:@"TCL"]) {
            interpreter = @"/usr/bin/tclsh";
        }
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if(!fileManager) {
        DSLog(@"Failed to execute '%@'", path);
		*errorString = NSLocalizedString(@"Failed executing shell script!", @"");
		return NO;
    }
        
    // ensure that the discovered interpreter is valid
    // and is executable
    [fileManager isExecutableFileAtPath:interpreter];
    if ([interpreter isEqualToString:@""] || ![fileManager isExecutableFileAtPath:interpreter]) {
        // can't determine how to run the script
        DSLog(@"Failed to execute '%@' because ControlPlane cannot determine how to do so.  Please use '#!/bin/bash' or similar in the script or rename the script with a file extension", path);
        *errorString = NSLocalizedString(@"Unable to determine interpreter for shell script!", @"");
		return NO;
    }
    
    // seems like everything is in order, launch the task
    NSTask *task = [NSTask launchedTaskWithLaunchPath:interpreter arguments:args];
	[task waitUntilExit];
	
	if ([task terminationStatus] != 0) {
		DLog(@"Failed to execute '%@'", path);
		*errorString = NSLocalizedString(@"Failed executing shell script!", @"");
		return NO;
	}

	return YES;
}

+ (NSString *)helpText
{
	return NSLocalizedString(@"The parameter for ShellScript actions is the full path of the "
				 "shell script, which will be executed with /bin/sh.", @"");
}

- (id)initWithFile:(NSString *)file
{
	self = [self init];
	[path release];
	path = [file copy];
	return self;
}

@end
