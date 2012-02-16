//
//  NSString+ShellScriptHelper.m
//  ControlPlane
//
//  Created by Dustin Rue on 1/15/12.
//  Shamelessly refactored from David Jennes's work
//  Copyright (c) 2012. All rights reserved.
//

#import "NSString+ShellScriptHelper.h"

@implementation NSString (ShellScriptHelper)

- (NSMutableArray *) interpreterFromFile {
	NSError *readFileError;
	
	// get lines
	NSString *fileContents = [NSString stringWithContentsOfFile: self
													   encoding: NSUTF8StringEncoding
														  error: &readFileError];
	NSArray *fileLines = [fileContents componentsSeparatedByString:@"\n"];
	
	// get the shebang line
	if (fileLines.count == 0)
		return nil;
	NSString *firstLine = [fileLines objectAtIndex: 0];
	firstLine = [firstLine stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	// check first line while handling a special case where the first line is:
	if ([firstLine rangeOfString: @"#!"].location == NSNotFound && ![firstLine isEqualToString:@":"]) 
		return nil;
	
	NSMutableArray *args = nil;
	
	// TRIVIA, first check if the file starts with a colon. Apparently
	// using a colon at the top of a script is allowed under POSIX. This a bit of a hack.
	if ([firstLine isEqualToString:@":"])
		args = [NSMutableArray arrayWithObject:@"#!/bin/sh"];
	else {
		// split shebang and it's parameters
		args = [[firstLine componentsSeparatedByString: @" "] mutableCopy];
		[args removeObject: @""];
	}
	
	// remove shebang characters #!
	if ([[args objectAtIndex: 0] length] > 2)
		[args replaceObjectAtIndex: 0
						withObject: [[args objectAtIndex: 0] substringFromIndex: 2]];
	// or there might have been a space between #! and the interpreter
	// so the first item in args is just '#!'
	else
		[args removeObjectAtIndex: 0];
	
	return args;
}

- (NSString *) interpreterFromExtension {
	static NSDictionary *extensionToInterpreter = nil;
	
	if (!extensionToInterpreter)
		[NSDictionary dictionaryWithObjectsAndKeys:
		 @"sh", @"/bin/bash",
		 @"scpt", @"/usr/bin/osascript",
		 @"pl", @"/usr/bin/perl",
		 @"py", @"/usr/bin/python",
		 @"php", @"/usr/bin/php",
		 @"expect", @"/usr/bin/expect",
		 @"tcl", @"/usr/bin/tclsh", nil];
	
	// Get the file type of the script
	NSString *app, *extension;
	if (![NSWorkspace.sharedWorkspace getInfoForFile: self application: &app type: &extension])
		return @"/bin/bash";
	extension = extension.lowercaseString;
	
	// Map extension
	NSString *result = [extensionToInterpreter objectForKey: extension];
	if (!result)
		result = @"/bin/bash";
	
	return result;
}

- (NSString *) findInterpreterWithArguments: (NSArray *) arguments intoArguments: (out NSArray **) fullArguments {
	if (!fullArguments)
		return @"";
	
	NSString *interpreter = nil;
	
	// add "--" to the start so that the shell won't try to parse arguments
	NSMutableArray *args = [arguments mutableCopy];
	[args insertObject:@"--" atIndex: 0];
	
	// interpret shebang line
	NSMutableArray *shebangArgs = [self interpreterFromFile];
	if (shebangArgs && shebangArgs.count > 0) {
		// get interpreter
		interpreter = [shebangArgs objectAtIndex: 0];
		[shebangArgs removeObjectAtIndex: 0];
		
		// and it's parameters (append our arguments)0
		if (shebangArgs.count > 0) {
			[shebangArgs addObjectsFromArray: args];
			args = shebangArgs;
		}
	}
    
    // backup routine to try using the file extension if it exists
    if (!interpreter)
		interpreter = [self interpreterFromExtension];
	
	// return results
	*fullArguments = args;
	return interpreter;
}

@end
