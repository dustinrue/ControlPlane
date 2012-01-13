//
//  ShellScriptAction.m
//  ControlPlane
//
//  Created by David Symonds on 23/04/07.
//

#import "DSLogger.h"
#import "ShellScriptAction.h"

@interface ShellScriptAction (Private)

- (NSString *) interpreterFromExtension: (NSString *) extension;

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
	
	// Get the file type of the script
    NSString *app, *fileType;
	if (![NSWorkspace.sharedWorkspace getInfoForFile: scriptPath application: &app type: &fileType]) {
		*errorString = [NSString stringWithFormat: NSLocalizedString(@"Failed opening '%@'.", @""), path];
		return NO;
	}
    
    // ControlPlane is going to attempt to peek inside the script to figure
    // out what interpreter needs to be called, if that fails
    // it'll attempt to determine the interpreter using the script's extension
    NSError *readFileError;
    NSString *fileContents = [NSString stringWithContentsOfFile: scriptPath
													   encoding: NSUTF8StringEncoding
														  error: &readFileError];
	NSArray *fileLines = [fileContents componentsSeparatedByString:@"\n"];
    
    // try to find the interpreter in file
	if (fileLines.count > 0) {
		NSString *firstLine = [fileLines objectAtIndex: 0];
		firstLine = [firstLine stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		if ([firstLine rangeOfString: @"#!"].location != NSNotFound) {
			// split shebang and it's parameters
			NSMutableArray *shebangArgs = [[[firstLine componentsSeparatedByString: @" "] mutableCopy] autorelease];
			[shebangArgs removeObject: @""];
			
			// extract interpreter
			interpreter = [[shebangArgs objectAtIndex: 0] substringFromIndex: 2];
			[shebangArgs removeObjectAtIndex: 0];
			
			// it's possible that there was a space between #! and the interpreter
			if (interpreter.length == 0) {
				interpreter = [shebangArgs objectAtIndex: 0];
				[shebangArgs removeObjectAtIndex: 0];
			}
			DSLog(@"Using interpreter from shebang: %@", interpreter);
			
			// extract args
			if (shebangArgs.count > 1) {
				[shebangArgs addObjectsFromArray: args];
				args = shebangArgs;
			}
		}
	}
    
    // backup routine to try using the file extension if it exists
    if ([interpreter isEqualToString:@""])
		interpreter = [self interpreterFromExtension: fileType];
    
    NSFileManager *fileManager = NSFileManager.defaultManager;
    if (!fileManager) {
        DSLog(@"Failed to execute '%@'", path);
		*errorString = NSLocalizedString(@"Failed executing shell script!", @"");
		return NO;
    }
        
    // ensure that the discovered interpreter is valid and executable
    if ([interpreter isEqualToString: @""] || ![fileManager isExecutableFileAtPath:interpreter]) {
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
 * Try to find a correct interpreter for known file types
 */
- (NSString *) interpreterFromExtension: (NSString *) extension {
	extension = extension.lowercaseString;
	NSString *result = @"/bin/bash";
	
	if ([extension isEqualToString: @"sh"])
		result = @"/bin/bash";
	else if ([extension isEqualToString:@"scpt"])
		result = @"/usr/bin/osascript";
	else if ([extension isEqualToString:@"pl"])
		result = @"/usr/bin/perl";
	else if ([extension isEqualToString:@"py"])
		result = @"/usr/bin/python";
	else if ([extension isEqualToString:@"php"])
		result = @"/usr/bin/php";
	else if ([extension isEqualToString:@"expect"])
		result = @"/usr/bin/expect";
	else if ([extension isEqualToString:@"tcl"])
		result = @"/usr/bin/tclsh";
	
	return result;
}

@end
