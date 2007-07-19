//
//  GenericEvidenceSource.h
//  MarcoPolo
//
//  Created by David Symonds on 19/07/07.
//

#import <Cocoa/Cocoa.h>
#import "EvidenceSourceWithCustomPanel.h"


@interface GenericEvidenceSource : EvidenceSourceWithCustomPanel {
	IBOutlet NSTextField *suggestionLeadText;
	IBOutlet NSArrayController *ruleParameterController;
}

- (id)init;

// Need to be implemented by descendant classes
//- (NSString *)getSuggestionLeadText:(NSString *)type;
//- (NSArray *)getSuggestions;

@end
