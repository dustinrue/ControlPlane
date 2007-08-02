//
//  AboutPanel.m
//  MarcoPolo
//
//  Created by David Symonds on 2/08/07.
//

#import <WebKit/WebFrame.h>
#import "AboutPanel.h"


@implementation AboutPanel

- (id)init
{
	if (!(self = [super init]))
		return nil;

	// load nib
	NSNib *nib = [[[NSNib alloc] initWithNibNamed:@"AboutPanel" bundle:nil] autorelease];
	if (!nib) {
		NSLog(@"%@ >> failed loading nib!", [self class]);
		return nil;
	}
	NSArray *topLevelObjects = [NSArray array];
	if (![nib instantiateNibWithOwner:self topLevelObjects:&topLevelObjects]) {
		NSLog(@"%@ >> failed instantiating nib!", [self class]);
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
		NSLog(@"%@ >> failed to find an NSPanel in nib!", [self class]);
		return nil;
	}

	NSData *data = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Credits" ofType:@"html"]];
	[[webView mainFrame] loadData:data
			     MIMEType:@"text/html"
		     textEncodingName:@"utf-16"
			      baseURL:[NSURL URLWithString:@""]];

	return self;
}

- (void)dealloc
{
	[panel release];

	[super dealloc];
}

- (void)runPanel
{
	[panel makeKeyAndOrderFront:self];
}

- (NSString *)versionString
{
	return [[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleShortVersionString"];
}

@end
