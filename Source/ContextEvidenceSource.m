//
//  ContextEvidenceSource.m
//  ControlPlane
//
//  Created by Dustin Rue on 4/15/14.
//
//

#import "ContextEvidenceSource.h"
#import "ContextsDataSource.h"
#import "CPController.h"

@implementation ContextEvidenceSource

- (id)init {
    self = [super init];
    
    if (!self)
        return self;
    
    return self;
}


- (void)start {
    running = YES;
    dataCollected = YES;
    
    return;
    
}
- (void)stop {
    running = NO;

}


- (NSString *)name {
    return @"ActiveContext";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule {
    NSSet *activeContexts = [CPController sharedActiveContexts];
    __block BOOL found = NO;
    
    [activeContexts enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
        if ([[obj name] isEqualToString:[rule valueForKey:@"parameter"]])
            found = YES;
    }];

    return found;
}

- (NSString *)getSuggestionLeadText:(NSString *)type {
    return NSLocalizedString(@"The following context is active", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions {
    NSDictionary *contexts = [[[ContextsDataSource alloc] init] getAllContexts];

    NSMutableArray *array = [NSMutableArray arrayWithCapacity:[contexts count]];
    
	[contexts enumerateKeysAndObjectsUsingBlock:^(id key, Context *obj, BOOL *stop) {

		NSString *identifier = [obj name];

		NSString *desc = [obj name];
		[array addObject:
         [NSDictionary dictionaryWithObjectsAndKeys:
          [self name], @"type",
          identifier, @"parameter",
          desc, @"description", nil]];

    }];
	
    
	return array;
}

- (NSString *) friendlyName {
    return NSLocalizedString(@"Active Context", @"");
}


@end
