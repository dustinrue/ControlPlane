//
//  Common.m
//  MarcoPolo
//
//  Created by David Symonds on 7/11/07.
//

#import "Common.h"


BOOL isLeopardOrLater()
{
	long major, minor;

	if (Gestalt(gestaltSystemVersionMajor, &major) || Gestalt(gestaltSystemVersionMinor, &minor))
		return NO;	// fallback

	return ((major > 10) || (major == 10 && minor >= 5));
}
