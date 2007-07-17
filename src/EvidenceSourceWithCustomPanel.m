//
//  EvidenceSourceWithCustomPanel.m
//  MarcoPolo
//
//  Created by David Symonds on 17/07/07.
//

#import "EvidenceSourceWithCustomPanel.h"


@interface EvidenceSourceWithCustomPanel (Private)

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo;

@end

#pragma mark -

@implementation EvidenceSourceWithCustomPanel

- (id)initWithNibNamed:(NSString *)name
{
	if (!(self = [super init]))
		return nil;

	// load nib
	NSNib *nib = [[[NSNib alloc] initWithNibNamed:name bundle:nil] autorelease];
	if (!nib) {
		NSLog(@"%@ >> failed loading nib named '%@'!", [self class], name);
		return nil;
	}
	NSArray *topLevelObjects = [NSArray array];
	if (![nib instantiateNibWithOwner:self topLevelObjects:&topLevelObjects]) {	// XXX: correct owner?
		NSLog(@"%@ >> failed instantiating nib (named '%@')!", [self class], name);
		return nil;
	}

	// Look for an NSPanel
	panel = nil;
	NSEnumerator *en = [topLevelObjects objectEnumerator];
	NSObject *obj;
	while ((obj = [en nextObject])) {
		if ([obj isKindOfClass:[NSPanel class]] && !panel)
			panel = (NSPanel *) [obj retain];
	}
	if (!panel) {
		NSLog(@"%@ >> failed to find an NSPanel in nib named '%@'!", [self class], name);
		return nil;
	}

	return self;
}

- (void)dealloc
{
	[panel release];

	[super dealloc];
}

- (id)runPanelAsSheetOfWindow:(NSWindow *)window withParameter:(id)parameter
{
	[self putParameterToPanel:parameter];

	[NSApp beginSheet:panel modalForWindow:window modalDelegate:self didEndSelector:nil contextInfo:nil];

	return [self getParameterFromPanel];
}

- (IBAction)closeSheet:(id)sender
{
	[NSApp endSheet:panel returnCode:0];
	[panel orderOut:nil];
}

- (id)getParameterFromPanel
{
	[NSException raise:@"Abstract Class Exception"
		    format:[NSString stringWithFormat:@"Error, -%@ not implemented.", _cmd]];
	return nil;
}

- (void)putParameterToPanel:(id)parameter
{
	[NSException raise:@"Abstract Class Exception"
		    format:[NSString stringWithFormat:@"Error, -%@ not implemented.", _cmd]];
}

@end
