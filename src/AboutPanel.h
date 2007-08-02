//
//  AboutPanel.h
//  MarcoPolo
//
//  Created by David Symonds on 2/08/07.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebView.h>


@interface AboutPanel : NSObject {
	NSPanel *panel;
	IBOutlet WebView *webView;
}

- (id)init;
- (void)dealloc;

- (void)runPanel;

- (NSString *)versionString;

@end
