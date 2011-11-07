//
//  ShellScriptEvidenceSource.m
//  ControlPlane
//
//  Created by Dustin Rue 8/5/2011.
//
// This evidence source allows the end user to create
// their own custom evidence source using an external program,
// or script.  Anything can be used so long as it returns 0
// for false and 1 for true.

#import "ShellScriptEvidenceSource.h"
#import "DSLogger.h"


@interface ShellScriptEvidenceSource (Private)


@end


@implementation ShellScriptEvidenceSource



- (id)init {
    self = [super initWithNibNamed:@"ShellScriptRule"];
    if (!self)
        return nil;
    
    running = NO;
    [self setDataCollected: NO];
    
	return self;
}


- (void)dealloc {

	[super dealloc];
}

- (void)start {
    running = YES;
    [self setDataCollected:true];
	
}

- (void)stop {    
    running = NO;
}


- (void)doUpdate {
}

- (NSString *)name {
	return @"ShellScript";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule {
    return false;

}

- (NSMutableDictionary *)readFromPanel {
    
}

- (void)writeToPanel:(NSDictionary *)dict usingType:(NSString *)type {
    
}


- (void)clearCollectedData {
    
}


@end
