//
//  PopButton.m
//  ControlPlane
//
//  Created by David Symonds on 26/04/07.
//
//  Modified by VladimirTechMan (Vladimir Beloborodov) on 22 May 2014.
//
//  IMPORTANT: This code is intended to be compiled for the ARC mode
//

#import "PopButton.h"

@implementation PopButton

- (void)mouseDown:(NSEvent *)theEvent
{
	if (![self isEnabled] || (self.menu == nil)) {
		return;
    }
    
	NSRect rect = [self bounds];
	NSPoint pt = NSMakePoint(rect.origin.x, rect.origin.y + rect.size.height + 5);
	NSEvent *event = [NSEvent mouseEventWithType:[theEvent type]
                                        location:[self convertPoint:pt toView:nil]
                                   modifierFlags:[theEvent modifierFlags]
                                       timestamp:[theEvent timestamp]
                                    windowNumber:[theEvent windowNumber]
                                         context:[theEvent context]
                                     eventNumber:[theEvent eventNumber]
                                      clickCount:[theEvent clickCount]
                                        pressure:[theEvent pressure]];
    
	[self highlight:YES];
	[NSMenu popUpContextMenu:self.menu withEvent:event forView:self];
	[self highlight:NO];
}

- (void)mouseUp:(NSEvent *)theEvent
{
	if ([self isEnabled]) {
		[self highlight:NO];
    }
}

@end
