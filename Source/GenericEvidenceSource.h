//
//  GenericEvidenceSource.h
//  ControlPlane
//
//  Created by David Symonds on 19/07/07.
//

#import "EvidenceSource.h"


@interface GenericEvidenceSource : EvidenceSource {
	IBOutlet NSTextField *suggestionLeadText;
	IBOutlet NSArrayController *ruleParameterController;
}

- (id)init;

// Need to be implemented by descendant classes
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;	// returns an NSArray of NSDictionary: keys are type, parameter, description

@end
