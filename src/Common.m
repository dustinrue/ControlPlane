//
//  Common.m
//  MarcoPolo
//
//  Created by David Symonds on 7/11/07.
//

#include <stdlib.h>
#include <sys/utsname.h>
#import "Common.h"


BOOL isLeopardOrLater()
{
	struct utsname name;

	if (uname(&name) != 0) {
		NSLog(@"WARNING: uname(3) failed (errno=%d)!", errno);
		return NO;
	}

	// name.release will be something like "8.10.1" (Tiger), or "9.0.0" (Leopard).
	// We just check for the first digit.
	if (strtol(name.release, NULL, 10) >= 9)
		return YES;

	return NO;
}
