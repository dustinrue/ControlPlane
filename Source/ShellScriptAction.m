//
//  ShellScriptAction.m
//  ControlPlane
//
//  Created by David Symonds on 23/04/07.
//

#import "DSLogger.h"
#import "ShellScriptAction.h"

@interface ShellScriptAction (Private)

- (NSMutableArray *) interpreterFromFile: (NSString *) file;
- (NSString *) interpreterFromExtension: (NSString *) file;

@end

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
    NSString *interpreter = @"";
	
    // Split on "|", add "--" to the start so that the shell won't try to parse arguments
	NSMutableArray *args = [[[path componentsSeparatedByString:@"|"] mutableCopy] autorelease];
	[args insertObject:@"--" atIndex:0];
	NSString *scriptPath = [args objectAtIndex: 1];
    
    // ControlPlane is going to attempt to peek inside the script to figure out
	// what interpreter needs to be called
    NSMutableArray *shebangArgs = [self interpreterFromFile: scriptPath];
	if (shebangArgs) {
		// get interpreter
		interpreter = [shebangArgs objectAtIndex: 0];
		[shebangArgs removeObjectAtIndex: 0];
		
		// and it's parameters
		if (shebangArgs.count > 0) {
			[shebangArgs addObjectsFromArray: args];
			args = shebangArgs;
		}
	}
    
    // backup routine to try using the file extension if it exists
    if ([interpreter isEqualToString: @""])
		interpreter = [self interpreterFromExtension: scriptPath];
    
    // ensure that the discovered interpreter is valid and executable
    if ([interpreter isEqualToString: @""] || ![NSFileManager.defaultManager isExecutableFileAtPath:interpreter]) {
        // can't determine how to run the script
        DSLog(@"Failed to execute '%@' because ControlPlane cannot determine how to do so.  Please use '#!/bin/bash' or similar in the script or rename the script with a file extension", path);
        *errorString = NSLocalizedString(@"Unable to determine interpreter for shell script!", @"");
		return NO;
    }
    
    // seems like everything is in order, launch the task
    NSTask *task = [NSTask launchedTaskWithLaunchPath:interpreter arguments:args];
	[task waitUntilExit];
	
	if (task.terminationStatus != 0) {
		DSLog(@"Failed to execute '%@'", path);
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
	self = [super init];
	[path release];
	path = [file copy];
	return self;
}

#pragma mark - Private methods

/**
 * Try to parse the shebang line inside the file
 * @return Returns array with interpereter and it's parameters (or nil)
 */
- (NSMutableArray *) interpreterFromFile: (NSString *) file {
	NSError *readFileError;
	
	// get lines
    NSString *fileContents = [NSString stringWithContentsOfFile: file
													   encoding: NSUTF8StringEncoding
														  error: &readFileError];
	NSArray *fileLines = [fileContents componentsSeparatedByString:@"\n"];
	
	// get the shebang line
	if (fileLines.count == 0)
		return nil;
	NSString *firstLine = [fileLines objectAtIndex: 0];
	firstLine = [firstLine stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	// check first line
	if ([firstLine rangeOfString: @"#!"].location == NSNotFound)
		return nil;
	
	// split shebang and it's parameters
	NSMutableArray *args = [[[firstLine componentsSeparatedByString: @" "] mutableCopy] autorelease];
	[args removeObject: @""];
	
	// remove shebang characterss #!
	if ([[args objectAtIndex: 0] length] > 2)
		[args replaceObjectAtIndex: 0
						withObject: [[args objectAtIndex: 0] substringFromIndex: 2]];
	// or there might have been a space between #! and the interpreter
	// so the first item in args is just '#!'
	else
		[args removeObjectAtIndex: 0];
	
	return args;
}

/**
 * Try to find a correct interpreter based on the file's extension
 * @return Returns the interpreter (or by default /bin/bash)
 */
- (NSString *) interpreterFromExtension: (NSString *) file {
    NSString *app, *extension;
	NSString *result = @"/bin/bash";
	
	// Get the file type of the script
	if (![NSWorkspace.sharedWorkspace getInfoForFile: file application: &app type: &extension])
		return result;
	extension = extension.lowercaseString;
	
	// check type
	if ([extension isEqualToString: @"sh"])
		result = @"/bin/bash";
	else if ([extension isEqualToString: @"scpt"])
		result = @"/usr/bin/osascript";
	else if ([extension isEqualToString: @"pl"])
		result = @"/usr/bin/perl";
	else if ([extension isEqualToString: @"py"])
		result = @"/usr/bin/python";
	else if ([extension isEqualToString: @"php"])
		result = @"/usr/bin/php";
	else if ([extension isEqualToString: @"expect"])
		result = @"/usr/bin/expect";
	else if ([extension isEqualToString: @"tcl"])
		result = @"/usr/bin/tclsh";
	
	return result;
}

@end
