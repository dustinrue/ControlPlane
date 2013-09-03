//
//  AboutPanel.h
//  ControlPlane
//
//  Created by David Symonds on 2/08/07.
//

#import <WebKit/WebView.h>


@interface AboutPanel : NSObject

- (id)init;

- (void)runPanel;

- (NSString *)versionString;
- (NSString *)gitCommit;

@end
