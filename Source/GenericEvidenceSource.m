//
//  GenericEvidenceSource.m
//  ControlPlane
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

- (NSString *) description {
    return NSLocalizedString(@"No description provided", @"");
}

- (NSMutableDictionary *)readFromPanel
{
	NSMutableDictionary *dict = [super readFromPanel];

	id sel = [[ruleParameterController arrangedObjects] objectAtIndex:[ruleParameterController selectionIndex]];
	[dict setValue:[sel valueForKey:@"parameter"] forKey:@"parameter"];
	[dict setValue:[sel valueForKey:@"type"] forKey:@"type"];
	if (![dict objectForKey:@"description"])
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
	NSEnumerator *en = [[self getSuggestions] objectEnumerator];
	NSDictionary *suggestion;
	while ((suggestion = [en nextObject])) {
		if (![[suggestion valueForKey:@"type"] isEqualToString:useType])
			continue;
		[ruleParameterController addObject:suggestion];
	}
	if (![dict objectForKey:@"parameter"])
		[ruleParameterController selectNext:self];
	else {
		// Pick the current parameter
		en = [[ruleParameterController arrangedObjects] objectEnumerator];
		unsigned int index = 0;
		NSDictionary *elt;
		NSObject *thisParam = [dict valueForKey:@"parameter"];
		while ((elt = [en nextObject])) {
			// TODO: Check that this test is correct!
			if ([[elt valueForKey:@"parameter"] isEqualTo:thisParam])
				break;
			++index;
		}
		if (elt) {
			// Found!
			[ruleParameterController setSelectionIndex:index];
		} else {
			// Push existing one in, since it isn't there
			[ruleParameterController setSelectsInsertedObjects:YES];
			[ruleParameterController addObject:dict];
		}
	}
}

- (NSString *)getSuggestionLeadText:(NSString *)type
{
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (NSArray *)getSuggestions
{
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

@end
