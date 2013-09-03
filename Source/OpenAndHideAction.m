//
//  OpenAndHideAction.m
//  ControlPlane
//
//  Created by Vladimir Beloborodov on 2/07/2013.
//
//  IMPORTANT: This code is intended to be compiled for the ARC mode
//

#import "OpenAndHideAction.h"

@implementation OpenAndHideAction

- (NSWorkspaceLaunchOptions)launchOptions {
    return NSWorkspaceLaunchDefault | NSWorkspaceLaunchAndHide;
}

+ (NSString *)helpText {
	return NSLocalizedString(@"The parameter for OpenAndHide actions is the full path of the"
                             " object to be opened, such as an application or a document.", @"");
}

+ (NSString *)friendlyName {
    return NSLocalizedString(@"Open File or Application and Hide", @"");
}

@end
