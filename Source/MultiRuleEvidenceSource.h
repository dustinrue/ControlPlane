//
//  MultiRuleEvidenceSource.h
//  ControlPlane
//
//  Created by Vladimir Beloborodov on 03/03/2013.
//

#import "EvidenceSource.h"

@interface MultiRuleEvidenceSource : EvidenceSource

- (id)init;
- (id)initWithPanel:(NSPanel *)initPanel;
- (id)initWithNibNamed:(NSString *)name;

- (id)initWithRules:(NSArray *)ruleTypeClasses;
- (void)dealloc;

- (BOOL)matchesRulesOfType:(NSString *)type;
- (NSArray *)typesOfRulesMatched;

- (BOOL)doesRuleMatch:(NSMutableDictionary *)rule;

- (NSMutableDictionary *)readFromPanel;
- (void)setContextMenu:(NSMenu *)menu;
- (void)writeToPanel:(NSDictionary *)rule usingType:(NSString *)type;

@end
