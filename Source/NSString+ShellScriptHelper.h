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
 * @
 */
- (NSString *) interpreterFromExtension;

@end

