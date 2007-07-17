//
//  EvidenceSourceWithCustomPanel.m
//  MarcoPolo
//
//  Created by David Symonds on 17/07/07.
//

#import "EvidenceSourceWithCustomPanel.h"


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

	// Look for an NSPanel (required), and an NSObjectController (optional)
	panel = nil;
	objectController = nil;
	NSEnumerator *en = [topLevelObjects objectEnumerator];
	NSObject *obj;
	while ((obj = [en nextObject])) {
		if ([obj isKindOfClass:[NSPanel class]] && !panel)
			panel = (NSPanel *) [obj retain];
		else if ([obj isKindOfClass:[NSObjectController class]] && !objectController)
			objectController = (NSObjectController *) [obj retain];
	}
	if (!panel) {
		NSLog(@"%@ >> failed to find an NSPanel in nib named '%@'!", [self class], name);
		if (objectController)
			[objectController release];
		return nil;
	}

	return self;
}

- (void)dealloc
{
	[panel release];
	if (objectController)
		[objectController release];

	[super dealloc];
}

@end
