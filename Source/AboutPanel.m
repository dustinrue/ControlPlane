//
//  AboutPanel.m
//  ControlPlane
//
//  Created by David Symonds on 2/08/07.
//
//  IMPORTANT: This code is intended to be compiled for the ARC mode
//

#import <WebKit/WebFrame.h>
#import "AboutPanel.h"


@implementation AboutPanel {
	NSPanel *panel;
	IBOutlet WebView *webView;
}

- (id)init {
	if (!(self = [super init]))
		return nil;

	// load nib
	NSNib *nib = [[NSNib alloc] initWithNibNamed:@"AboutPanel" bundle:nil];
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
	for (NSObject *obj in topLevelObjects) {
		if ([obj isKindOfClass:[NSPanel class]] && !panel) {
			panel = (NSPanel *) obj;
        }
	}
	if (!panel) {
		NSLog(@"%@ >> failed to find an NSPanel in nib!", [self class]);
		return nil;
	}

	[webView.mainFrame loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:
		[[NSBundle mainBundle] pathForResource:@"Credits" ofType:@"html"]]]];

	return self;
}

- (void)runPanel {
	[panel makeKeyAndOrderFront:self];
}

- (NSString *)versionString {
	return [[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleShortVersionString"];
}

- (NSString *)gitCommit {
	NSString *path = [[NSBundle mainBundle] pathForResource:@"Build" ofType:@"plist"];
	NSDictionary *plist = [[NSString stringWithContentsOfFile:path
                                                     encoding:NSUTF8StringEncoding error:nil] propertyList];
	return [plist valueForKey:@"GitCommit"];
}

@end
