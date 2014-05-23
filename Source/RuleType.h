//
//  RuleType.h
//  ControlPlane
//
//  Created by VladimirTechMan on 03/03/2013.
//
//

#import "EvidenceSource.h"

@interface RuleType : NSObject

@property (nonatomic,weak,readonly) EvidenceSource *evidenceSource; // weak
@property (nonatomic,retain,readonly) NSPanel *panel;

// To be implemented by descendant classes.
+ (NSString *)panelNibName;

- (id)initWithEvidenceSource:(EvidenceSource *)src;

// To be implemented by descendant classes.
- (NSString *)name;

// To be implemented by descendant classes.
- (BOOL)doesRuleMatch:(NSMutableDictionary *)rule;

+ (void)alertWithMessage:(NSString *)msg informativeText:(NSString *)infoText;
+ (void)alertOnInvalidParamValueWith:(NSString *)msg;

// Optional to implement in descendant classes.
// Intended to preprocess the values in panel's controls and check if they are valid.
// (If a parameter is not valid, then show an appropriate message and return NO.)
// If not implemented, then the parameters are always considered valid.
- (BOOL)validatePanelParams;

- (IBAction)closeSheetWithOK:(id)sender;
- (IBAction)closeSheetWithCancel:(id)sender;

// To be implemented by descendant classes.
// Create rule description from panel's controls' values or from rule[@"parameter"].
- (NSString *)getDefaultDescription:(NSDictionary *)rule;

- (BOOL)canAutoupdateDescription:(NSString *)description ofRule:(NSDictionary *)rule;

// To be implemented by descendant classes.
// rule[@"parameter"] *must* be filled in.
// To fill in rule descriptions, please, implement method getDefaultDescription: .
- (void)readFromPanelInto:(NSMutableDictionary *)rule;

- (void)setContextMenu:(NSMenu *)menu;

// To be implemented by descendant classes.
- (void)writeToPanel:(NSDictionary *)rule;

@end
