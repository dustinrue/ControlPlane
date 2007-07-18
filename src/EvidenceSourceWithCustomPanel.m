//
//  EvidenceSourceWithCustomPanel.m
//  MarcoPolo
//
//  Created by David Symonds on 17/07/07.
//

#import "EvidenceSourceWithCustomPanel.h"


@interface EvidenceSourceWithCustomPanel (Private)

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

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

- (void)setContextMenu:(NSMenu *)menu
{
	[ruleContext setMenu:menu];
}

- (void)runPanelAsSheetOfWindow:(NSWindow *)window withParameter:(NSDictionary *)parameter
		 callbackObject:(NSObject *)callbackObject selector:(SEL)selector
{
	[self writeToPanel:parameter];

	NSMethodSignature *sig = [callbackObject methodSignatureForSelector:selector]; 
	NSInvocation *contextInfo = [NSInvocation invocationWithMethodSignature:sig];
	[contextInfo setSelector:selector];
	[contextInfo setTarget:callbackObject];

	[NSApp beginSheet:panel
	   modalForWindow:window
	    modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
	      contextInfo:[contextInfo retain]];
}

- (IBAction)closeSheetWithOK:(id)sender
{
	[NSApp endSheet:panel returnCode:NSOKButton];
	[panel orderOut:nil];
}

- (IBAction)closeSheetWithCancel:(id)sender
{
	[NSApp endSheet:panel returnCode:NSCancelButton];
	[panel orderOut:nil];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode != NSOKButton)
		return;

	NSInvocation *inv = (NSInvocation *) contextInfo;
	NSDictionary *dict = [self readFromPanel];
	[inv setArgument:&dict atIndex:2];

	[inv invoke];
	[inv release];
}

- (NSMutableDictionary *)readFromPanel
{
	return [NSMutableDictionary dictionaryWithObjectsAndKeys:
		[[ruleContext selectedItem] representedObject], @"context",
		[NSNumber numberWithDouble:[ruleConfidenceSlider doubleValue]], @"confidence",
		[[self typesOfRulesMatched] objectAtIndex:0], @"type",
		nil];
}

- (void)writeToPanel:(NSDictionary *)dict
{
	if ([dict objectForKey:@"context"]) {
		// Set up context selector
		// TODO: set menu properly?
		int index = [ruleContext indexOfItemWithRepresentedObject:[dict valueForKey:@"context"]];
		[ruleContext selectItemAtIndex:index];
	}

	if ([dict objectForKey:@"confidence"]) {
		// Set up confidence slider
		[ruleConfidenceSlider setDoubleValue:[[dict valueForKey:@"confidence"] doubleValue]];
	}
}

@end
