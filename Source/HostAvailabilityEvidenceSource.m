//
//  HostAvailabilityEvidenceSource.m
//  ControlPlane
//
//  Created by Dustin Rue on 8/1/13.
//
//

#import "HostAvailabilityEvidenceSource.h"
#import "RuleType.h"
#import "DSLogger.h"


@implementation HostAvailabilityEvidenceSource

static void HostAvailabilityReachabilityCallBack(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info) {
    
#if DEBUG_MODE
    NSLog(@"host reachability: %c via: %c%c%c%c%c%c%c\n",
          (flags & kSCNetworkReachabilityFlagsReachable)            ? 'R' : '-',
          (flags & kSCNetworkReachabilityFlagsTransientConnection)  ? 't' : '-',
          (flags & kSCNetworkReachabilityFlagsConnectionRequired)   ? 'c' : '-',
          (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic)  ? 'C' : '-',
          (flags & kSCNetworkReachabilityFlagsInterventionRequired) ? 'i' : '-',
          (flags & kSCNetworkReachabilityFlagsConnectionOnDemand)   ? 'D' : '-',
          (flags & kSCNetworkReachabilityFlagsIsLocalAddress)       ? 'l' : '-',
          (flags & kSCNetworkReachabilityFlagsIsDirect)             ? 'd' : '-'
          );
#endif
    NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
    
    BOOL hostIsReachable = (flags & kSCNetworkFlagsReachable && !(flags & kSCNetworkFlagsTransientConnection)) ? YES:NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"hostAvailabilityChanged" object:@{@"target" : [NSValue value:&target withObjCType:@encode(void *)], @"availability" : [NSNumber numberWithBool:hostIsReachable]}];
    
    [autoreleasePool release];
}

- (id)init
{
	if (!(self = [super initWithNibNamed:@"HostAvailability"]))
		return nil;
    

    self.monitoredHosts = [NSMutableDictionary dictionary];
    
	return self;
}

- (void) dealloc {
    [_monitoredHosts release];
    [super dealloc];
}

- (void) hostAvailabilityHasChanged:(NSNotification *) context
{
    @synchronized(self) {
        NSDictionary *data = [context object];
        
        [self.monitoredHosts enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            NSValue *currentTarget = obj[@"target"];
            if ([currentTarget isEqualTo:data[@"target"]]) {
                NSMutableDictionary *mutableMonitoredHosts = [self.monitoredHosts mutableCopy];
                [mutableMonitoredHosts setObject:@{@"available" : data[@"availability"], @"target" : currentTarget} forKey:key];
                self.monitoredHosts = mutableMonitoredHosts;
                [mutableMonitoredHosts release];
            }
        }];
    }
    return;
}

- (void) start
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(hostAvailabilityHasChanged:)
                                                 name:@"hostAvailabilityChanged"
                                               object:nil];
    
    @synchronized (self) {
        NSArray *myRules = [self myRules];
        
        for (NSDictionary *rule in myRules) {
            [self addMonitoredHost:rule[@"parameter"]];
        }
        
        running = YES;
        dataCollected = YES;
    }
    return;
}

- (void) addMonitoredHost:(NSString *) hostToMonitor
{
    NSMutableDictionary *mutableMonitoredHosts = [self.monitoredHosts mutableCopy];
    SCNetworkReachabilityRef monitoredHost = SCNetworkReachabilityCreateWithName(CFAllocatorGetDefault(), [hostToMonitor cStringUsingEncoding:NSUTF8StringEncoding]);
    
    if (SCNetworkReachabilitySetCallback(monitoredHost, HostAvailabilityReachabilityCallBack, NULL)) {
        if (SCNetworkReachabilityScheduleWithRunLoop(monitoredHost, CFRunLoopGetMain(), kCFRunLoopDefaultMode)) {
            DSLog(@"monitoring host %@", hostToMonitor);
            [mutableMonitoredHosts setObject:@{@"available" : [NSNumber numberWithBool:NO], @"target" : [NSValue value:&monitoredHost withObjCType:@encode(void *)]} forKey:hostToMonitor];
        }
        else {
            DSLog(@"failed to monitor host %@", hostToMonitor);
        }
    }
    
    self.monitoredHosts = mutableMonitoredHosts;
    [mutableMonitoredHosts release];

}

- (IBAction)closeSheetWithOK:(id)sender
{
    if ([self validatePanelParams]) {
        [super closeSheetWithOK:sender];
    }
}

- (BOOL)validatePanelParams
{
    NSString *param = [self.hostOrIp stringValue];
    param = [param stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self.hostOrIp setStringValue:param];
    
    if ([param length] == 0) {
        [RuleType alertOnInvalidParamValueWith:NSLocalizedString(@"Host name cannot be empty", @"")];
        return NO;
    }
    
    return YES;
}

- (NSMutableDictionary *)readFromPanel
{
    NSMutableDictionary *dict = [super readFromPanel];
    
    NSString *param = [self.hostOrIp stringValue];
	[dict setValue:param forKey:@"parameter"];
	if (![dict objectForKey:@"description"]) {
		[dict setValue:param forKey:@"description"];
    }
    
    [self addMonitoredHost:param];
	return dict;
}

- (void) stop
{
    [self.monitoredHosts enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSValue *encodedMonitoredHost = obj[@"target"];
        SCNetworkReachabilityRef monitoredHost;
        [encodedMonitoredHost getValue:&monitoredHost];
        if (SCNetworkReachabilityUnscheduleFromRunLoop(monitoredHost, CFRunLoopGetMain(), kCFRunLoopDefaultMode))
            DSLog(@"stopped monitoring %@", key);
        else
            DSLog(@"failed to stop monitoring %@", key);
    }];
    [self.monitoredHosts removeAllObjects];
    self.dataCollected = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"hostAvailabilityChanged" object:nil];
    running = NO;
}

- (NSString *)getSuggestionLeadText:(NSString *)type
{
	return NSLocalizedString(@"Enter hostname or IP address", @"In rule-adding dialog");
}

- (void)writeToPanel:(NSDictionary *)dict usingType:(NSString *)type
{
	[super writeToPanel:dict usingType:type];
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule
{
    return [self.monitoredHosts[rule[@"parameter"]][@"available"] boolValue];
}

- (NSString *) name
{
    return @"HostAvailability";
}

- (NSString *) friendlyName
{
    return @"Host Availability";
}

@end
