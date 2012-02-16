//
//  NSString+ShellScriptHelper.h
//  ControlPlane
//
//  Created by Dustin Rue on 1/15/12.
//  Copyright (c) 2012. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (ShellScriptHelper)

/**
 * Try to parse the shebang line inside the file
 * @return Returns array with interpereter and it's parameters (or nil)
 */
- (NSMutableArray *) interpreterFromFile;

/**
 * Try to find a correct interpreter based on the file's extension
 * @return Returns the found interpreter (default is bash)
 */
- (NSString *) interpreterFromExtension;

/**
 * Try to find a correct interpreter for a script (using either the shebang line
 * or the file's extension).
 * @param[in] arguments Arguments for the interpreter
 * @param[out] fullArguments Arguments for the interpreter, prepended with shebang arguments
 * @result The found interpreter
 */
- (NSString *) findInterpreterWithArguments: (NSArray *) arguments intoArguments: (out NSArray **) fullArguments;

@end
