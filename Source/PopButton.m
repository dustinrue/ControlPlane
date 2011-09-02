//
//  PopButton.m
//  ControlPlane
//
//  Created by David Symonds on 26/04/07.
//

#import "PopButton.h"


@implementation PopButton

- (id)init
{
	if (!(self = [super init]))
		return nil;

	menu = nil;

	return self;
}

- (void)dealloc
{
	if (menu)
		[menu release];
	[super dealloc];
}

- (NSMenu *)menu
{
	return menu;
}

- (void)setMenu:(NSMenu *)theMenu
{
	[theMenu retain];
	if (menu)
		[menu release];
	menu = theMenu;
}

- (void)mouseDown:(NSEvent *)theEvent
{
	if (![self isEnabled] || !menu)
		return;

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
	[NSMenu popUpContextMenu:menu withEvent:event forView:self];
	[self highlight:NO];
}

- (void)mouseUp:(NSEvent *)theEvent
{
	if ([self isEnabled])
		[self highlight:NO];
}

@end
