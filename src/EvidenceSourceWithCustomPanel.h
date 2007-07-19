//
//  EvidenceSourceWithCustomPanel.h
//  MarcoPolo
//
//  Created by David Symonds on 17/07/07.
//

#import <Cocoa/Cocoa.h>
#import "EvidenceSource.h"


@interface EvidenceSourceWithCustomPanel : EvidenceSource {
	NSPanel *panel;

	IBOutlet NSPopUpButton *ruleContext;
	IBOutlet NSSlider *ruleConfidenceSlider;
}

- (id)initWithNibNamed:(NSString *)name;
- (void)dealloc;

- (void)setContextMenu:(NSMenu *)menu;
- (void)runPanelAsSheetOfWindow:(NSWindow *)window withParameter:(NSDictionary *)parameter
		 callbackObject:(NSObject *)callbackObject selector:(SEL)selector;
- (IBAction)closeSheetWithOK:(id)sender;
- (IBAction)closeSheetWithCancel:(id)sender;

// Need to be extended by descendant classes
// (need to add handling of 'parameter', and optionally 'type' and 'description' keys)
- (NSMutableDictionary *)readFromPanel;
- (void)writeToPanel:(NSDictionary *)dict usingType:(NSString *)type;

@end
