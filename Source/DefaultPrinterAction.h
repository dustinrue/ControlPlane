//
//  DefaultPrinterAction.h
//  ControlPlane
//
//  Created by David Symonds on 3/04/07.
//  Reworked by Vladimir Beloborodov (VladimirTechMan) on 20-21 Aug 2013.
//

#import "Action.h"

@interface DefaultPrinterAction : Action <ActionWithLimitedOptions>

- (id)initWithDictionary:(NSDictionary *)dict;
- (id)initWithOption:(NSString *)option;

- (NSMutableDictionary *)dictionary;

- (NSString *)description;
- (BOOL)execute:(NSString **)errorString;
+ (NSString *)helpText;
+ (NSString *)creationHelpText;

+ (NSArray *)limitedOptions;

@end
