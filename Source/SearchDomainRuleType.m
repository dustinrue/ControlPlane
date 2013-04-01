//
//  SearchDomainRuleType.m
//  ControlPlane
//
//  Created by VladimirTechMan on 03/03/2013.
//
//

#import "DNSEvidenceSource.h"
#import "SearchDomainRuleType.h"


@implementation SearchDomainRuleType {
    // For custom panel
    IBOutlet NSComboBox *domainComboBox;
    IBOutlet NSButton *wildcardCheckBox;
}

+ (NSString *)panelNibName {
    return @"SearchDomainRule";
}

- (void)dealloc {
    [super dealloc];
}

- (NSString *)name {
    return NSLocalizedString(@"DNS Search Domain", @"");
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule {
    NSString *domainName = rule[@"parameter"];
	if (!domainName) {
		return NO;	// corrupted rule
    }

    DNSEvidenceSource *evidenceSource = (DNSEvidenceSource *) self.evidenceSource;
    if (![(NSNumber *) rule[@"parameter.isWildcard"] boolValue]) {
        return [evidenceSource.searchDomains containsObject:domainName];
    }

    __block BOOL match = NO;
    [evidenceSource.searchDomains enumerateObjectsUsingBlock:^(NSString *domain, BOOL *stop) {
        *stop = match = [domain hasSuffix:domainName];
    }];
    return match;
}

- (BOOL)validatePanelParams {
    NSString *domain = [domainComboBox stringValue];
    domain = [domain stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [domainComboBox setStringValue:domain];

    if (![domain length]) {
        [[self class] alertOnInvalidParamValueWith:NSLocalizedString(@"Search domain cannot be empty", @"")];
        return NO;
    }
    return YES;
}

- (void)readFromPanelInto:(NSMutableDictionary *)rule {
    [super readFromPanelInto:rule];
    rule[@"parameter"] = [domainComboBox stringValue];
    rule[@"parameter.isWildcard"] = @([wildcardCheckBox intValue]);
}

- (NSString *)getDefaultDescription:(NSDictionary *)rule {
    NSString *domainName = [domainComboBox stringValue];
    if ([wildcardCheckBox intValue]) {
        return [@"*" stringByAppendingString:domainName];
    }
    return domainName;
}

- (void)writeToPanel:(NSDictionary *)rule {
    [super writeToPanel:rule];

	NSArray *currentDomains = [((DNSEvidenceSource *) self.evidenceSource).searchDomains allObjects];

	[domainComboBox removeAllItems];
	[domainComboBox addItemsWithObjectValues:currentDomains];

	NSString *domainName = rule[@"parameter"];
	if (domainName) {
        if (![currentDomains containsObject:domainName]) {
            [domainComboBox addItemWithObjectValue:domainName];
        }
        [domainComboBox selectItemWithObjectValue:domainName];
	} else if ([currentDomains count]) {
		domainName = [currentDomains objectAtIndex:0];
    } else {
        domainName = @"";
    }

    NSNumber *isWildcard = rule[@"parameter.isWildcard"];
    if (!isWildcard) {
        isWildcard = @(NO);
    }

    [domainComboBox setStringValue:domainName];
    [wildcardCheckBox setIntValue:[isWildcard intValue]];
}

@end
