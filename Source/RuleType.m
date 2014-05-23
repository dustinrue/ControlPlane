//
//  RuleType.m
//  ControlPlane
//
//  Created by VladimirTechMan on 03/03/2013.
//
//  IMPORTANT: This code is intended to be compiled for the ARC mode
//

#import "EvidenceSource.h"
#import "RuleType.h"

@interface RuleType ()

@property (nonatomic,weak) IBOutlet NSPopUpButton *ruleContext;
@property (nonatomic,weak) IBOutlet NSSlider *ruleConfidenceSlider;
@property (nonatomic,weak) IBOutlet NSButton *negateRule;

@end

@implementation RuleType

+ (void)alertWithMessage:(NSString *)msg informativeText:(NSString *)infoText
{
    NSAlert *alert = [NSAlert new];
    [alert setMessageText:msg];
    [alert setInformativeText:infoText];
    [alert runModal];
}

+ (void)alertOnInvalidParamValueWith:(NSString *)msg
{
    [self alertWithMessage:msg informativeText:NSLocalizedString(@"Provide a valid parameter value", @"")];
}

+ (NSString *)panelNibName
{
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (id)initWithEvidenceSource:(EvidenceSource *)src
{
	if ([[self class] isEqualTo:[RuleType class]]) {
		[NSException raise:@"Abstract Class Exception"
                    format:@"Error, attempting to instantiate RuleType directly."];
	}

    NSString *nibName = [[self class] panelNibName];
    if (!nibName) {
        NSLog(@"%@ >> no nib name provided!", [self class]);
        return nil;
    }

    self = [super init];
    if (self == nil) {
        return nil;
    }

    _evidenceSource = src;
    _panel = [EvidenceSource getPanelFromNibNamed:nibName instantiatedWithOwner:self];
    if (_panel == nil) {
        self = nil;
        return nil;
    }

    return self;
}

- (BOOL)validatePanelParams
{
    return YES;
}

- (IBAction)closeSheetWithOK:(id)sender
{
    if ([self validatePanelParams]) {
        [NSApp endSheet:self.panel returnCode:NSOKButton];
        [self.panel orderOut:nil];
    }
}

- (IBAction)closeSheetWithCancel:(id)sender
{
	[NSApp endSheet:self.panel returnCode:NSCancelButton];
	[self.panel orderOut:nil];
}

- (NSString *)name
{
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (BOOL)doesRuleMatch:(NSMutableDictionary *)rule
{
	[self doesNotRecognizeSelector:_cmd];
	return NO;
}

- (void)readFromPanelInto:(NSMutableDictionary *)rule
{
    NSPopUpButton *strongRuleContext = self.ruleContext;
    NSSlider *strongRuleConfidenceSlider = self.ruleConfidenceSlider;
    NSButton *strongNegateRule = self.negateRule;
    
    rule[@"context"] = [[strongRuleContext selectedItem] representedObject];
    rule[@"confidence"] = @([strongRuleConfidenceSlider doubleValue]);
    rule[@"negate"] = [NSNumber numberWithInteger:[strongNegateRule state]];
}

- (NSString *)getDefaultDescription:(NSDictionary *)rule
{
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (BOOL)canAutoupdateDescription:(NSString *)description ofRule:(NSDictionary *)rule
{
    return [description isEqualToString:[self getDefaultDescription:rule]];
}

- (void)setContextMenu:(NSMenu *)menu
{
    NSPopUpButton *strongRuleContext = self.ruleContext;
    [strongRuleContext setMenu:menu];
}

- (void)writeToPanel:(NSDictionary *)rule
{
    // Set up context selector
    id context = rule[@"context"];
	if (context != nil) {
        NSPopUpButton *strongRuleContext = self.ruleContext;
		[strongRuleContext selectItemAtIndex:[strongRuleContext indexOfItemWithRepresentedObject:context]];
	}
    
    // Set up confidence slider
    id confidence = rule[@"confidence"];
	if (confidence != nil) {
        NSSlider *strongRuleConfidenceSlider = self.ruleConfidenceSlider;
		[strongRuleConfidenceSlider setDoubleValue:[confidence doubleValue]];
	}
    
    id negate = rule[@"negate"];
    if (negate != nil) {
        NSButton *strongNegateRule = self.negateRule;
        [strongNegateRule setState:[negate integerValue]];
    }
}

@end
