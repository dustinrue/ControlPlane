//
//  NSString+ShellScriptHelper.m
//  ControlPlane
//
//  Created by Dustin Rue on 1/15/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
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

- (NSString *) interpreterFromExtension {
    NSString *app, *extension;
	NSString *result = @"/bin/bash";
	
	// Get the file type of the script
	if (![NSWorkspace.sharedWorkspace getInfoForFile: self application: &app type: &extension])
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


