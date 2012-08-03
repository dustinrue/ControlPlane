//
//  SampleESPlugin.m
//  SampleESPlugin
//
//  Created by Dustin Rue on 8/1/12.
//  Copyright (c) 2012 Dustin Rue. All rights reserved.
//

#import "SampleESPlugin.h"

@implementation SampleESPlugin

@synthesize screenIsLocked;

- (id) init {
    self = [super init];
    
    if (self) {
        NSLog(@"hello from the plugin!");
    }
    
    return self;
}

- (NSString *)getSuggestionLeadText:(NSString *)type {
    return @"";
}

- (NSArray *)getSuggestions {
    return [NSArray array];
}

- (NSArray *)typesOfRulesMatched
{
	return [NSArray arrayWithObject:[self name]];
}

- (NSString *)name {
    return @"SampleESPlugin";
}

- (BOOL) isRunning {
    return NO;
}

- (BOOL)matchesRulesOfType:(NSString *)type {
	return [[self typesOfRulesMatched] containsObject:type];
}

- (NSString *) friendlyName {
    return @"Sample Evidence Source Plugin";
}


- (void) start {
    
}


- (void) stop {
    
}

- (NSArray *)myRules {
    return [NSArray array];
}

- (NSMutableDictionary *)readFromPanel {
    return [NSMutableDictionary dictionary];
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule {
    return NO;
}

- (void)writeToPanel:(NSDictionary *)dict usingType:(NSString *)type {
    return;
}

@end
