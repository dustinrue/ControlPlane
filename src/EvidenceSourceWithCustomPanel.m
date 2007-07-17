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

- (void)runPanelAsSheetOfWindow:(NSWindow *)window withParameter:(id)parameter
		storingResultIn:(id)object parameterKeyPath:(NSString *)parameterKeyPath
	     descriptionKeyPath:(NSString *)descriptionKeyPath typeKeyPath:(NSString *)typeKeyPath
{
	[self putParameterToPanel:parameter];

	NSArray *contextInfo = [[NSArray alloc] initWithObjects:
		object, parameterKeyPath, descriptionKeyPath, typeKeyPath, nil];
	[NSApp beginSheet:panel
	   modalForWindow:window
	    modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
	      contextInfo:contextInfo];
}

- (IBAction)closeSheet:(id)sender
{
	[NSApp endSheet:panel returnCode:0];
	[panel orderOut:nil];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	NSArray *bits = (NSArray *) contextInfo;
	id object = [bits objectAtIndex:0];
	NSString *parameterKeyPath = [bits objectAtIndex:1];
	NSString *descriptionKeyPath = [bits objectAtIndex:2];
	NSString *typeKeyPath = [bits objectAtIndex:3];

	id param = [self getParameterFromPanel];
	NSString *desc = [self descriptionOfParameterInPanel];
	NSString *type = [self typeOfParameterInPanel];

#ifdef DEBUG_MODE
	NSLog(@"%@ >> stuffing '%@' into %@ at %@", [self class], param, object, parameterKeyPath);
#endif
	[object setValue:param forKeyPath:parameterKeyPath];
#ifdef DEBUG_MODE
	NSLog(@"%@ >> stuffing '%@' into %@ at %@", [self class], desc, object, descriptionKeyPath);
#endif
	[object setValue:desc forKeyPath:descriptionKeyPath];

	[object setValue:type forKeyPath:typeKeyPath];
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

- (NSString *)descriptionOfParameterInPanel
{
	// Default implementation
	return [NSString stringWithFormat:@"%@", [self getParameterFromPanel]];
}

- (NSString *)typeOfParameterInPanel
{
	// Default implementation
	return [[self typesOfRulesMatched] objectAtIndex:0];
}

@end
