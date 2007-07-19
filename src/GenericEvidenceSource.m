//
//  GenericEvidenceSource.m
//  MarcoPolo
//
//  Created by David Symonds on 19/07/07.
//

#import "GenericEvidenceSource.h"


@implementation GenericEvidenceSource

- (id)init
{
	if (!(self = [super initWithNibNamed:@"GenericRule"]))
		return nil;

	return self;
}

- (NSMutableDictionary *)readFromPanel
{
	NSMutableDictionary *dict = [super readFromPanel];

	id sel = [ruleParameterController selection];
	[dict setValue:[sel valueForKey:@"parameter"] forKey:@"parameter"];
	[dict setValue:[sel valueForKey:@"type"] forKey:@"type"];
	[dict setValue:[sel valueForKey:@"description"] forKey:@"description"];

	return dict;
}

- (void)writeToPanel:(NSDictionary *)dict usingType:(NSString *)type
{
	[super writeToPanel:dict usingType:type];

	NSString *useType = type;
	if (!useType) {
		if ([dict objectForKey:@"type"])
			useType = [dict valueForKey:@"type"];
		else
			useType = [[self typesOfRulesMatched] objectAtIndex:0];
	}

	[suggestionLeadText setStringValue:[self getSuggestionLeadText:useType]];

	[ruleParameterController removeObjects:[ruleParameterController arrangedObjects]];
	[ruleParameterController addObjects:[self getSuggestions]];
	[ruleParameterController selectNext:self];
}

@end
