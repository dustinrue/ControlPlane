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

- (NSMutableArray *) interpreterFromFile
{
    NSError *readFileError;
	
	// get lines
    NSString *fileContents = [NSString stringWithContentsOfFile: self
													   encoding: NSUTF8StringEncoding
														  error: &readFileError];
	NSArray *fileLines = [fileContents componentsSeparatedByString:@"\n"];
	
	// get the shebang line
	if (fileLines.count == 0) {
		return nil;
    }
    
	NSString *firstLine = fileLines[0];
	firstLine = [firstLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	// check first line while handling a special case where the first line is :
	if ([firstLine rangeOfString: @"#!"].location == NSNotFound && ![firstLine isEqualToString:@":"]) {
        return nil;
    }
    
    NSMutableArray *args = nil;
    
    // TRIVIA, first check if the file starts with a colon.  Apparently
    // using a colon at the top of a script is allowed under POSIX.  This a bit of a hack.
    if ([firstLine isEqualToString:@":"]) {
        args = [NSMutableArray arrayWithObject:@"#!/bin/sh"];
    }
    else {
        // split shebang and it's parameters
        args = [[firstLine componentsSeparatedByString:@" "] mutableCopy];
        [args removeObject: @""];
    }

	
	// remove shebang characterss #!
	if ([args[0] length] > 2) {
		[args replaceObjectAtIndex:0 withObject:[args[0] substringFromIndex:2]];
    }
	// or there might have been a space between #! and the interpreter
	// so the first item in args is just '#!'
	else {
		[args removeObjectAtIndex:0];
    }
	
	return args;
    
}

- (NSString *) interpreterFromExtension
{
    NSString *app, *extension;
	NSString *result = @"/bin/bash";
	
	// Get the file type of the script
	if (![NSWorkspace.sharedWorkspace getInfoForFile: self application: &app type: &extension]) {
		return result;
    }
	extension = extension.lowercaseString;
	
	// check type
	if ([extension isEqualToString: @"sh"])
		result = @"/bin/bash";
	else if ([extension isEqualToString: @"zsh"])
		result = @"/usr/bin/zsh";
	else if ([extension isEqualToString: @"rb"])
		result = @"/usr/bin/ruby";
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


