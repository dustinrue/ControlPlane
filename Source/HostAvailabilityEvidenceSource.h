//
//  HostAvailabilityEvidenceSource.h
//  ControlPlane
//
//  Created by Dustin Rue on 8/1/13.
//
//

#import "EvidenceSource.h"
#import <SystemConfiguration/SCNetworkReachability.h>

@interface HostAvailabilityEvidenceSource : EvidenceSource

@property (assign) SCNetworkReachabilityRef monitoredHost;
@property (retain) NSMutableDictionary *monitoredHosts;
@property (assign) BOOL hostIsReachable;
@property (assign) IBOutlet NSComboBox *hostOrIp;


@end
