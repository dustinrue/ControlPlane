//
//  RuleType.m
//  ControlPlane
//
//  Created by VladimirTechMan on 03/03/2013.
//
//

#import "EvidenceSource.h"
#import "RuleType.h"

@implementation RuleType {
    // for each rule panel
    IBOutlet NSPopUpButton *ruleContext;
    IBOutlet NSSlider *ruleConfidenceSlider;
}

+ (void)alertWithMessage:(NSString *)msg informativeText:(NSString *)infoText {
    NSAlert *alert = [[NSAlert new] autorelease];
    [alert setMessageText:msg];
    [alert setInformativeText:infoText];
    [alert runModal];
}

+ (void)alertOnInvalidParamValueWith:(NSString *)msg {
    [self alertWithMessage:msg informativeText:NSLocalizedString(@"Provide a valid parameter value", @"")];
}

+ (NSString *)panelNibName {
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (id)initWithEvidenceSource:(EvidenceSource *)src {
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
    if (!self) {
        return nil;
    }

    _evidenceSource = src;
    _panel = [[EvidenceSource getPanelFromNibNamed:nibName instantiatedWithOwner:self] retain];
    if (!_panel) {
        [self release];
        return nil;
    }

    return self;
}

- (void)dealloc {
    [_panel release];

    [super dealloc];
}

- (BOOL)validatePanelParams {
    return YES;
}

- (IBAction)closeSheetWithOK:(id)sender {
    if ([self validatePanelParams]) {
        [NSApp endSheet:self.panel returnCode:NSOKButton];
        [self.panel orderOut:nil];
    }
}

- (IBAction)closeSheetWithCancel:(id)sender {
	[NSApp endSheet:self.panel returnCode:NSCancelButton];
	[self.panel orderOut:nil];
}

- (NSString *)name {
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule {
	[self doesNotRecognizeSelector:_cmd];
	return NO;
}

- (void)readFromPanelInto:(NSMutableDictionary *)rule {
    rule[@"context"] = [[ruleContext selectedItem] representedObject];
    rule[@"confidence"] = @([ruleConfidenceSlider doubleValue]);
}

- (NSString *)getDefaultDescription:(NSDictionary *)rule {
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (BOOL)canAutoupdateDescription:(NSString *)description ofRule:(NSDictionary *)rule {
    return [description isEqualToString:[self getDefaultDescription:rule]];
}

- (void)setContextMenu:(NSMenu *)menu {
    [ruleContext setMenu:menu];
}

- (void)writeToPanel:(NSDictionary *)rule {
    // Set up context selector
    id context = rule[@"context"];
	if (context) {
		[ruleContext selectItemAtIndex:[ruleContext indexOfItemWithRepresentedObject:context]];
	}

    // Set up confidence slider
    id confidence = rule[@"confidence"];
	if (confidence) {
		[ruleConfidenceSlider setDoubleValue:[confidence doubleValue]];
	}
}

@end
