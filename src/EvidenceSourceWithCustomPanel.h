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
}

- (id)initWithNibNamed:(NSString *)name;
- (void)dealloc;

- (void)runPanelAsSheetOfWindow:(NSWindow *)window withParameter:(id)parameter
		storingResultIn:(id)object parameterKeyPath:(NSString *)parameterKeyPath
	     descriptionKeyPath:(NSString *)descriptionKeyPath typeKeyPath:(NSString *)typeKeyPath;
- (IBAction)closeSheet:(id)sender;

// Need to be implemented by descendant classes
- (id)getParameterFromPanel;
- (void)putParameterToPanel:(id)parameter;
- (NSString *)descriptionOfParameterInPanel;	// optional
- (NSString *)typeOfParameterInPanel;		// optional

@end
