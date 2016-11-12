//
//  StressTestEvidenceSource.m
//  ControlPlane
//
//  Created by Dustin Rue on 9/21/12.
//
//

#import "StressTestEvidenceSource.h"

@implementation StressTestEvidenceSource


- (id)init
{
	if (!(self = [super init]))
		return nil;
    
	return self;
}

- (void)dealloc
{
    [_loopTimer release];
	[super dealloc];
}


- (NSString *) description {
    return NSLocalizedString(@"Enable this evidence source to cause ControlPlane to assume a large number of evidence source changes are occuring.", @"");
}


- (void)start
{
	if (running)
		return;
    
    [self setLoopTimer:[NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)0.001
                                                        target:self
                                                      selector:@selector(wtf:)
                                                      userInfo:nil
                                                       repeats:YES]];
	running = YES;
}

- (void) wtf:(NSTimer *) timer {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"evidenceSourceDataDidChange"
                                                                object:nil];
                                                      
}

- (void)stop
{
	if (!running)
		return;
    
    [[self loopTimer] invalidate];
    [self setLoopTimer:nil];
	running = NO;
}

- (NSString *)name
{
	return @"StressTest";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule {
    return NO;
}

- (NSString *)getSuggestionLeadText:(NSString *)type
{
	return NSLocalizedString(@"Just a stress test, you can't create rules", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions {    
    return [NSArray array];
}

- (NSString *) friendlyName {
    return NSLocalizedString(@"Do Update Stress Test", @"");
}

@end
