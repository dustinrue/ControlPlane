//
//  SliderWithValue.m
//  MarcoPolo
//
//  Created by David Symonds on 15/07/07.
//  Large chunks from http://www.cocoadev.com/index.pl?ToolTip
//

#import "SliderWithValue.h"


@implementation ToolTipTextField

- (void)drawRect:(NSRect)aRect
{
	[super drawRect:aRect];

	[[NSColor colorWithCalibratedWhite:0.925 alpha:1.0] set];
	NSFrameRect(aRect);
}

@end

#pragma mark -

static ToolTip *sharedToolTip = nil;

@interface ToolTip (Private)

- (void)setString:(NSString *)string forEvent:(NSEvent *)theEvent;

@end

@implementation ToolTip

+ (void)setString:(NSString *)string forEvent:(NSEvent *)theEvent
{
	if (!sharedToolTip)
		sharedToolTip = [[ToolTip alloc] init];

	[sharedToolTip setString:string forEvent:theEvent];
}

+ (void)release
{
	[sharedToolTip release];
	sharedToolTip = nil;
}

- (id)init
{
	if (!(self = [super init]))
		return nil;

	// These size are not really import, just the relation between the two...
	NSRect contentRect = { { 100, 100 }, { 100, 20 } };
	NSRect textFieldFrame = { { 0, 0 }, { 100, 20 } };

	window = [[NSWindow alloc] initWithContentRect:contentRect
					     styleMask:NSBorderlessWindowMask
					       backing:NSBackingStoreBuffered
						 defer:YES];

	[window setOpaque:NO];
	[window setAlphaValue:0.80];
	[window setBackgroundColor:[NSColor colorWithDeviceRed:1.0 green:0.96 blue:0.76 alpha:1.0]];
	[window setHasShadow:YES];
	[window setLevel:NSStatusWindowLevel];
	[window setReleasedWhenClosed:YES];
	[window orderFront:nil];

	textField = [[ToolTipTextField alloc] initWithFrame:textFieldFrame];
	[textField setEditable:NO];
	[textField setSelectable:NO];
	[textField setBezeled:NO];
	[textField setBordered:NO];
	[textField setDrawsBackground:NO];
	[textField setAlignment:NSCenterTextAlignment];
	[textField setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	[textField setFont:[NSFont toolTipsFontOfSize:[NSFont systemFontSize]]];
	[[window contentView] addSubview:textField];

	[textField setStringValue:@" "]; // Just having at least 1 char to allow the next message...
	textAttributes = [[[textField attributedStringValue] attributesAtIndex:0 effectiveRange:nil] retain];

	return self;
}

- (void)dealloc
{
	[window release];
	[textAttributes release];

	[super dealloc];
}

- (void)setString:(NSString *)string forEvent:(NSEvent *)theEvent
{
	NSSize size = [string sizeWithAttributes:textAttributes];
	NSPoint cursorScreenPosition = [[theEvent window] convertBaseToScreen:[theEvent locationInWindow]];

	[textField setStringValue:string];
	[window setFrameTopLeftPoint:NSMakePoint(cursorScreenPosition.x + 10, cursorScreenPosition.y + 28)];

	[window setContentSize:NSMakeSize(size.width + 20, size.height + 1)];
}

@end

#pragma mark -

@interface SliderWithValue (Private)

- (NSString *)toolTipText;

@end

@implementation SliderWithValue

- (NSString *)toolTipText
{
	NSNumberFormatter *nf = [[[NSNumberFormatter alloc] init] autorelease];
	[nf setFormatterBehavior:NSNumberFormatterBehavior10_4];
	[nf setNumberStyle:NSNumberFormatterPercentStyle];

	double val = [self doubleValue];
	if (val == 0.0)
		val = 0.001;	// HACK: the stupid number formatter leaves off the '%' if it's exactly zero!

	return [nf stringFromNumber:[NSDecimalNumber numberWithDouble:val]];
}

- (id)initWithCoder:(NSCoder *)decoder
{
	if (!(self = [super initWithCoder:decoder]))
		return nil;

	[self setContinuous:YES];
	[self setAction:@selector(doUpdate:)];
	[self setTarget:self];

	return self;
}

- (void)doUpdate:(id)sender
{
	[ToolTip setString:[self toolTipText] forEvent:[NSApp currentEvent]];

	if ([[NSApp currentEvent] type] == NSLeftMouseUp)
		[ToolTip release];
}

- (void)mouseDown:(NSEvent *)theEvent
{
	[ToolTip setString:[self toolTipText] forEvent:theEvent];

	[super mouseDown:theEvent];
}

@end
