//
//	LockKeychainAction.m
//	ControlPlane
//
//	Created by David Jennes on 02/09/11.
//	Copyright 2011. All rights reserved.
//

#import "LockKeychainAction.h"
#import <Security/Security.h>

@implementation LockKeychainAction


- (NSString *) description {
	if (turnOn)
		return NSLocalizedString(@"Locking default Keychain.", @"");
	else
		return NSLocalizedString(@"Unlocking default Keychain.", @"");
}

- (BOOL) execute: (NSString **) errorString {
	OSStatus error;
	
	if (turnOn) {
		// lock
		error = SecKeychainLock(NULL);
		if (error)
			*errorString = NSLocalizedString(@"Failed locking Kechain!", @"");
	} else {
		// unlock
		error = SecKeychainUnlock(NULL, 0, NULL, FALSE);
		if (error)
			*errorString = NSLocalizedString(@"Failed unlocking Keychain!", @"");
	}
	
	return (error == 0);
}

+ (NSString *) helpText {
	return NSLocalizedString(@"The parameter for LockKeychain actions is either \"1\" "
							 "or \"0\", depending on whether you want lock or unlock the "
							 "default Keychain.", @"");
}

+ (NSString *) creationHelpText {
	return @"Lock or unlock the default Keychain?";
}

+ (NSArray *) limitedOptions {
	return [NSArray arrayWithObjects:
			[NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithBool: YES], @"option",
			 NSLocalizedString(@"Lock", @""), @"description", nil],
			[NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithBool: NO], @"option",
			 NSLocalizedString(@"Unlock", @""), @"description", nil],
			nil];
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Lock Keychain", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"Keychain", @"");
}

@end
