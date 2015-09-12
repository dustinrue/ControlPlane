//
//  SliderWithValue.m
//  ControlPlane
//
//  Created by David Symonds on 15/07/07.
//  Large chunks from http://www.cocoadev.com/index.pl?ToolTip
//
//  IMPORTANT: This code is intended to be compiled for the ARC mode
//

#import "SliderWithValue.h"
#import "SharedNumberFormatter.h"

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

@interface ToolTip ()

- (void)setString:(NSString *)string atPoint:(NSPoint)point;

@end

@implementation ToolTip

+ (void)setString:(NSString *)string atPoint:(NSPoint)point
{
	if (sharedToolTip == nil) {
		sharedToolTip = [[ToolTip alloc] init];
    }

	[sharedToolTip setString:string atPoint:point];
}

+ (void)releaseToolTip
{
    sharedToolTip = nil;
}

- (id)init
{
	self = [super init];
    if (self == nil) {
		return nil;
    }
    
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
	textAttributes = [[textField attributedStringValue] attributesAtIndex:0 effectiveRange:nil];
    
	return self;
}

- (void)setString:(NSString *)string atPoint:(NSPoint)point
{
	NSSize size = [string sizeWithAttributes:textAttributes];

	[textField setStringValue:string];
	[window setFrameTopLeftPoint:NSMakePoint(point.x + 10, point.y + 28)];

	[window setContentSize:NSMakeSize(size.width + 20, size.height + 1)];
}


@end


#pragma mark -

static NSTimer *hideToolTipTimer;

@interface SliderCellWithValue ()

- (void) hideToolTip:(NSTimer *)theTimer;
- (void) doHideToolTip;

@end

@implementation SliderCellWithValue

+ (NSString *)toolTipTextForValue:(double)value {
	if (value == 0.0) {
		value = 1e-6;	// HACK: the stupid number formatter leaves off the '%' if it's exactly zero!
    }
	return [[SharedNumberFormatter percentStyleFormatter] stringFromNumber:[NSDecimalNumber numberWithDouble:value]];
}

- (void)drawKnob:(NSRect)knobRect
{
	[super drawKnob:knobRect];

	if (![self isHighlighted] || ([[NSApp currentEvent] window] != [[self controlView] window])) {
		return;
    }

	if ([[self controlView] isKindOfClass:[NSTableView class]]) {
		// If this cell is used as an NSTableView column cell, we get these drawKnob: events even when
		// other columns are edited. This is a bit of a hack to avoid showing tooltips
		NSTableView *tv = (NSTableView *) [self controlView];
		NSEvent *event = [NSApp currentEvent];
		NSPoint pt = [tv convertPoint:[event locationInWindow] fromView:[[event window] contentView]];
		//int col = [tv columnAtPoint:pt];
		if ((pt.x < knobRect.origin.x) || (pt.x > knobRect.origin.x + knobRect.size.width)) {
			return;
        }
	}

	NSEventType eventType = [[NSApp currentEvent] type];

	BOOL draw = NO;
	if ((eventType == NSLeftMouseDown) && (sharedToolTip == nil)) {
		draw = YES;
    } else if ((eventType == NSLeftMouseUp) && (sharedToolTip != nil)) {
		draw = NO;
    } else if (sharedToolTip != nil) {
		draw = YES;
    }

	if (draw) {
		NSRect r1 = [[self controlView] convertRect:knobRect toView:nil];
		NSPoint p1 = [[[self controlView] window] convertRectToScreen:r1].origin;
		float bump = [self knobThickness] / 2;
		p1.x += bump;
		p1.y += bump;
		[ToolTip setString:[[self class] toolTipTextForValue:[self doubleValue]] atPoint:p1];
        if (hideToolTipTimer == nil) {
            hideToolTipTimer = [NSTimer scheduledTimerWithTimeInterval: 5
                                                                 target: self
                                                               selector: @selector(hideToolTip:)
                                                               userInfo: nil
                                                                repeats: NO];
        }
	} else if (!draw && (sharedToolTip != nil)) {
        [self doHideToolTip];
    }
		
}

- (void) hideToolTip:(NSTimer *)theTimer {
    [self doHideToolTip];
    hideToolTipTimer = nil;
}

- (void) doHideToolTip {
    if (sharedToolTip != nil) {
        [ToolTip releaseToolTip];
    }
}

@end


#pragma mark -

@interface SliderWithValue ()

- (void)doUpdate:(id)sender;

@end

@implementation SliderWithValue

- (id)initWithCoder:(NSCoder *)decoder
{
	if (!(self = [super initWithCoder:decoder])) {
		return nil;
    }

	[self setContinuous:YES];
	[self setTarget:self];
	[self setAction:@selector(doUpdate:)];

	return self;
}

- (void)doUpdate:(id)sender
{
	NSEvent *theEvent = [NSApp currentEvent];
	//NSLog(@"cell is %@", [[self cell] class]);
    NSRect r1 = NSMakeRect([theEvent locationInWindow].x, [theEvent locationInWindow].y, 0, 0);

	NSPoint point = [[theEvent window] convertRectToScreen:r1].origin;

	if ([theEvent type] == NSLeftMouseUp) {
		[ToolTip releaseToolTip];
    } else {
		[ToolTip setString:[SliderCellWithValue toolTipTextForValue:[self doubleValue]] atPoint:point];
    }
}

@end
