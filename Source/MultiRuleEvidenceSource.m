//
//  MultiRuleEvidenceSource.m
//  ControlPlane
//
//  Created by Vladimir Beloborodov on 03/03/2013.
//

#import "MultiRuleEvidenceSource.h"
#import "RuleType.h"

@interface MultiRuleEvidenceSource ()

@property (nonatomic, retain) NSMenu *panelRuleContextMenu;

@end

@implementation MultiRuleEvidenceSource {
    NSDictionary *ruleTypes;
    NSArray *ruleTypeNames;

    // rule type corresponding to the current panel being shown
    RuleType *panelRuleType;
}

- (id)init {
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (id)initWithPanel:(NSPanel *)initPanel {
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (id)initWithNibNamed:(NSString *)name {
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (id)initWithRules:(NSArray *)ruleTypeClasses {
    self = [super initWithPanel:nil];
    if (!self) {
        return nil;
    }

    NSUInteger numOfRules = [ruleTypeClasses count];
    NSMutableDictionary *supportedTypes = [[NSMutableDictionary alloc] initWithCapacity:numOfRules];
    NSMutableArray *typeNames = [[NSMutableArray alloc] initWithCapacity:numOfRules];

    Class ruleTypeClass = [RuleType class];
    for (Class typeClass in ruleTypeClasses) {
        if (![typeClass isSubclassOfClass:ruleTypeClass]) {
            NSLog(@"%@ >> rule type class '%@' is not a subclass of RuleType!", [self class], typeClass);
            [typeNames release];
            [supportedTypes release];
            [self release];
            return nil;
        }

        RuleType *ruleType = [(RuleType *) [typeClass alloc] initWithEvidenceSource:self];
        if (!ruleType) {
            NSLog(@"%@ >> failed to create an object of class '%@'!", [self class], typeClass);
            [typeNames release];
            [supportedTypes release];
            [self release];
            return nil;
        }

        NSString *typeName = [ruleType name];
        supportedTypes[typeName] = ruleType;
        [typeNames addObject:typeName];
        [ruleType release]; // it has been retained by types
    }

    ruleTypes = (NSDictionary *) supportedTypes;
    ruleTypeNames = (NSArray *) typeNames;

    return self;
}

- (void)dealloc {
    panel = nil;
    [_panelRuleContextMenu release];
    [ruleTypeNames release];
    [ruleTypes release];

	[super dealloc];
}

- (BOOL)matchesRulesOfType:(NSString *)type {
    return (ruleTypes[type] != nil);
}

- (NSArray *)typesOfRulesMatched {
    return ruleTypeNames;
}

- (BOOL)doesRuleMatch:(NSMutableDictionary *)rule {
    NSString *typeName = rule[@"type"];
    if (!typeName) {
        NSLog(@"%@ >> no type specified in the rule to be matched!", [self class]);
        return NO;
    }

    RuleType *ruleType = ruleTypes[typeName];
    if (!ruleType) {
        NSLog(@"%@ >> rules of type '%@' are not supported by this evidence source!", [self class], typeName);
        return NO;
    }

    return [ruleType doesRuleMatch:rule];
}

- (NSMutableDictionary *)readFromPanel {
    NSMutableDictionary *rule = [super readFromPanel];

    rule[@"type"] = [panelRuleType name];
    [panelRuleType readFromPanelInto:rule];

    if (!rule[@"description"]) {
        rule[@"description"] = [panelRuleType getDefaultDescription:rule];
    }

    return rule;
}

- (void)setContextMenu:(NSMenu *)menu {
	self.panelRuleContextMenu = menu;
}

- (void)writeToPanel:(NSDictionary *)rule usingType:(NSString *)type {
    RuleType *ruleType = ruleTypes[type];
    if (!ruleType) {
        NSLog(@"%@ >> rules of type '%@' are not supported by this evidence source!", [self class], type);
        return;
    }

    panelRuleType = ruleType;
    [ruleType setContextMenu:self.panelRuleContextMenu];

    panel = ruleType.panel;
    [super writeToPanel:rule usingType:type];
    [ruleType writeToPanel:rule];

    if (oldDescription && [ruleType canAutoupdateDescription:oldDescription ofRule:rule]) {
        [oldDescription autorelease];
        oldDescription = nil;
    }
}

@end
