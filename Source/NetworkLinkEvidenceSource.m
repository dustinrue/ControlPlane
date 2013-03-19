//
//  NetworkLinkEvidenceSource.m
//  ControlPlane
//
//  Created by Mark Wallis on 25/07/07.
//  Tweaks by David Symonds on 25/07/07.
//

#import <SystemConfiguration/SystemConfiguration.h>
#import "NetworkLinkEvidenceSource.h"


#pragma mark C callbacks

static void linkChange(SCDynamicStoreRef store, CFArrayRef changedKeys,  void *info)
{
#ifdef DEBUG_MODE
	NSLog(@"linkChange called with changedKeys:\n%@", changedKeys);
#endif
	NetworkLinkEvidenceSource *src = (NetworkLinkEvidenceSource *) info;

    [src doFullUpdate:nil];
}

@implementation NetworkLinkEvidenceSource {
	NSLock *lock;
	NSMutableArray *interfaces;

    // To get network services
    SCPreferencesRef prefs;
	// For SystemConfiguration asynchronous notifications
	SCDynamicStoreRef store;
}


- (id)init
{
	if (!(self = [super init]))
		return nil;

	lock = [[NSLock alloc] init];
	interfaces = [[NSMutableArray alloc] init];

	return self;
}

- (void)dealloc
{
	[lock release];
	[interfaces release];

	[super dealloc];
}

- (NSArray *)enumerate
{
    // Get all interfaces from the Network Services prefs. This way
    // we capture interfaces that not currently present, such as
    // Thunderbolt network adapters.
    NSArray * services = (NSArray *)SCNetworkServiceCopyAll(prefs);
    NSMutableSet * inters = [NSMutableSet set];
	NSEnumerator *e = [services objectEnumerator];
    SCNetworkServiceRef service;
    
	while (service = (SCNetworkServiceRef) [e nextObject]) {
        SCNetworkInterfaceRef inter = SCNetworkServiceGetInterface(service);
		NSString *name = (NSString *) SCNetworkInterfaceGetBSDName(inter);
        if (name) {
            [inters addObject:name];
        }
    }
    [services release];

    NSMutableArray * subset = [NSMutableArray array];
    for (NSString * name in inters) {
        NSString * key = [NSString stringWithFormat:@"State:/Network/Interface/%@/Link", name];
        // Default state is 'inactive'. That way we capture a transition even if the link
        // disappeared completely, e.g. Thunderbolt adapter unplugged.
        NSString * opt = [NSString stringWithFormat:@"-%@", name];
        CFDictionaryRef current = SCDynamicStoreCopyValue(store, (CFStringRef)key);
        if (current) {
            if (CFDictionaryGetValue(current, CFSTR("Active")) == kCFBooleanTrue)
                opt = [NSString stringWithFormat:@"+%@", name];
            CFRelease(current);
        }
		[subset addObject:opt];
	}

	return subset;
}

- (void)doFullUpdate:(id)sender
{
	NSArray *inters = [self enumerate];

	[lock lock];
	[interfaces setArray:inters];
	[self setDataCollected:[interfaces count] > 0];
    //[[NSNotificationCenter defaultCenter] postNotificationName:@"evidenceSourceDataDidChange" object:nil];
	[lock unlock];
}

- (void)start
{
	if (running)
		return;

	// Register for asynchronous notifications
	SCDynamicStoreContext ctxt;
	ctxt.version = 0;
	ctxt.info = self;
	ctxt.retain = NULL;
	ctxt.release = NULL;
	ctxt.copyDescription = NULL;

	store = SCDynamicStoreCreate(NULL, CFSTR("ControlPlane"), linkChange, &ctxt);
    dispatch_queue_t queue = dispatch_queue_create("ControlPlane.NetworkLink", NULL);
    SCDynamicStoreSetDispatchQueue(store, queue);

    // Notify on link changes for all interfaces
    NSArray * patterns = @[ @"State:/Network/Interface/[[:alnum:]]+/Link" ];
	SCDynamicStoreSetNotificationKeys(store, NULL, (CFArrayRef) patterns);
	// TODO: catch errors

    // For retrieving network service later
    prefs = SCPreferencesCreate(NULL, CFSTR("ControlPlane"), NULL);

    dispatch_async(queue, ^{
        [self doFullUpdate:nil];
    });
    CFRelease(queue); // retained by 'store'


	running = YES;
}

- (void)stop
{
	if (!running)
		return;

    SCDynamicStoreSetDispatchQueue(store, NULL);
	CFRelease(store);
    CFRelease(prefs);

	[lock lock];
	[interfaces removeAllObjects];
	[self setDataCollected:NO];
	[lock unlock];

	running = NO;
}

- (NSString *)name
{
	return @"NetworkLink";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule
{
	BOOL match = NO;

	NSString *iface = [rule valueForKey:@"parameter"];

	[lock lock];
    match = [interfaces containsObject:iface];
	[lock unlock];

	return match;
}

- (NSString *)getSuggestionLeadText:(NSString *)type
{
	return NSLocalizedString(@"Network link on interface", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions
{
	NSMutableArray *arr = [NSMutableArray array];
	NSArray *all = [(NSArray *)SCNetworkServiceCopyAll(prefs) autorelease];
    // The above returns all services in all locations, and in random order,
    // so weed out duplicates and sort at the end to make more presentable.
    NSMutableSet * alreadySeen = [NSMutableSet set];

	NSEnumerator *en = [all objectEnumerator];
    SCNetworkServiceRef service;
	while ((service = (SCNetworkServiceRef) [en nextObject])) {
        SCNetworkInterfaceRef inter = SCNetworkServiceGetInterface(service);
		NSString *dev = (NSString *) SCNetworkInterfaceGetBSDName(inter);
		if (!dev)
			continue;
        if ([alreadySeen containsObject:dev])
            continue;
		NSString *name = (NSString *) SCNetworkInterfaceGetLocalizedDisplayName(inter);
		if (!name)
			name = [NSString stringWithFormat:@"%@?", dev];
		NSString *activeDesc = [NSString stringWithFormat:
			NSLocalizedString(@"%@ (%@) link active", @"In NetworkLinkEvidenceSource"), dev, name];
		NSString *inactiveDesc = [NSString stringWithFormat:
			NSLocalizedString(@"%@ (%@) link inactive", @"In NetworkLinkEvidenceSource"), dev, name];
		NSString *activeParam = [NSString stringWithFormat:@"+%@", dev];
		NSString *inactiveParam = [NSString stringWithFormat:@"-%@", dev];

		// Don't include interfaces that we couldn't enumerate
		if (![interfaces containsObject:activeParam] && ![interfaces containsObject:inactiveParam])
			continue;

		[arr addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			@"NetworkLink", @"type",
			activeParam, @"parameter",
			activeDesc, @"description", nil]];
		[arr addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			@"NetworkLink", @"type",
			inactiveParam, @"parameter",
			inactiveDesc, @"description", nil]];

        [alreadySeen addObject:dev];
	}

    [arr sortUsingDescriptors:@[ [NSSortDescriptor sortDescriptorWithKey:@"description" ascending:YES] ]];
	return arr;
}

- (NSString *) friendlyName {
    return NSLocalizedString(@"Active Network Adapter", @"");
}

@end
