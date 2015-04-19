//
//  RemoteDesktopEvidenceSource.m
//  ControlPlane
//
//  Created by Dustin Rue on 4/19/15.
//
//

#import "RemoteDesktopEvidenceSource.h"

@implementation RemoteDesktopEvidenceSource

- (id)init {
    self = [super init];
    if (self) {
        self.userConnected = NO;
    }
    return self;
}

- (void)start {
    if (running) {
        return;
    }
    

    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(doFullUpdate:)
                                                 name:@"com.apple.remotedesktop.viewerNames"
                                               object:nil];
    
    [self setDataCollected:YES];
    running = YES;
}

- (void)stop {
    if (!running) {
        return;
    }

    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"com.apple.remotedesktop.viewerNames"
                                                  object:nil];
    
    [self setDataCollected:NO];
    
    running = NO;
}

- (void)doFullUpdate:(NSNotification *)notification {
    
    NSArray *connectedUsers = [[notification userInfo] valueForKey:@"ViewerNames"];
    if ([connectedUsers count] == 0) {
        self.userConnected = NO;
    }
    else {
        self.userConnected = YES;
    }
    
    
    return;
}

- (NSString *)name {
    return @"RemoteDesktop";
}

- (NSString *)friendlyName {
    return NSLocalizedString(@"Remote Desktop", @"");
}


- (NSString *)description {
    return NSLocalizedString(@"Create rules based on if someone is connected using Remote Desktop.", @"");
}

- (NSArray *)getSuggestions {
    return @[
             @{ @"type": @"RemoteDesktop", @"parameter": @"Yes", @"description": NSLocalizedString(@"Yes", @"") },
             @{ @"type": @"RemoteDesktop", @"parameter": @"No",  @"description": NSLocalizedString(@"No", @"") },
             ];
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule {
    return self.userConnected;
}

- (NSString *)getSuggestionLeadText:(NSString *)type {
    return NSLocalizedString(@"Remote Desktop user is connected:", @"In rule-adding dialog");
}

@end
