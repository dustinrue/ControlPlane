//
//  HostAvailabilityEvidenceSource.m
//  ControlPlane
//
//  Created by Dustin Rue on 8/1/13.
//
//

#import "HostAvailabilityEvidenceSource.h"


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
    
    BOOL hostIsReachable = (flags & kSCNetworkFlagsReachable) ? YES:NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"hostAvailabilityChanged" object:@{@"target" : [NSValue value:&target withObjCType:@encode(void *)], @"availability" : [NSNumber numberWithBool:hostIsReachable]}];
    
    [autoreleasePool release];
}

- (id)init
{
	if (!(self = [super initWithNibNamed:@"HostAvailability"]))
		return nil;
    

    self.monitoredHosts = [NSDictionary dictionary];
    
	return self;
}

- (void) hostAvailabilityHasChanged:(NSNotification *) context {
    
    @synchronized(self) {
        NSDictionary *data = [context object];
        
        NSArray *allKeys = [self.monitoredHosts allKeys];
        
        for (NSString *currentKey in allKeys) {
            NSValue *currentTarget = self.monitoredHosts[currentKey][@"target"];
            if ([currentTarget isEqualTo:data[@"target"]]) {
                NSMutableDictionary *mutableMonitoredHosts = [self.monitoredHosts mutableCopy];
                [mutableMonitoredHosts setObject:@{@"available" : data[@"availability"], @"target" : currentTarget} forKey:currentKey];
                self.monitoredHosts = mutableMonitoredHosts;
                [mutableMonitoredHosts release];
            }
        }
    }
    
}

- (void) start {
    
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

- (void) addMonitoredHost:(NSString *) hostToMonitor {
    NSMutableDictionary *mutableMonitoredHosts = [self.monitoredHosts mutableCopy];
    SCNetworkReachabilityRef monitoredHost = SCNetworkReachabilityCreateWithName(CFAllocatorGetDefault(), [hostToMonitor cStringUsingEncoding:NSUTF8StringEncoding]);
    
    if (SCNetworkReachabilitySetCallback(monitoredHost, HostAvailabilityReachabilityCallBack, NULL))
        if (SCNetworkReachabilityScheduleWithRunLoop(monitoredHost, CFRunLoopGetMain(), kCFRunLoopDefaultMode)) {
            [mutableMonitoredHosts setObject:@{@"available" : [NSNumber numberWithBool:NO], @"target" : [NSValue value:&monitoredHost withObjCType:@encode(void *)]} forKey:hostToMonitor];
        }
    self.monitoredHosts = mutableMonitoredHosts;
    [mutableMonitoredHosts release];

}

- (NSMutableDictionary *)readFromPanel
{
	NSMutableDictionary *dict = [super readFromPanel];
    
    NSString *param = [self.hostOrIp stringValue];
	[dict setValue:param forKey:@"parameter"];
	if (![dict objectForKey:@"description"])
		[dict setValue:param forKey:@"description"];
    
    [self addMonitoredHost:param];
	return dict;
}

- (void) stop {
    
}

- (NSString *)getSuggestionLeadText:(NSString *)type
{
	return NSLocalizedString(@"Enter hostname or IP address", @"In rule-adding dialog");
}

- (void)writeToPanel:(NSDictionary *)dict usingType:(NSString *)type
{
	[super writeToPanel:dict usingType:type];
    
	
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule {
    return [self.monitoredHosts[rule[@"parameter"]][@"available"] boolValue];
}

- (NSString *) name {
    return @"HostAvailability";
}

- (NSString *) friendlyName {
    return @"Host Availability";
}
@end
