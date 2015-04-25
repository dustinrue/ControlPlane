//
//  MountedVolumeEvidenceSource.m
//  ControlPlane
//
//  Created by Dustin Rue on 6/19/14.
//
//  IMPORTANT: This code is intended to be compiled for the ARC mode
//

#import "MountedVolumeEvidenceSource.h"

@implementation MountedVolumeEvidenceSource

- (id)init {
    self = [super init];
    
    if (!self)
        return self;
    
    return self;
}


- (void)start {
    running = YES;

    self.mountedVolumes = [NSDictionary dictionary];
    
    [self volumeListDidChange:nil];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(volumeListDidChange:) name:NSWorkspaceDidMountNotification object:nil];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(volumeListDidChange:) name:NSWorkspaceDidUnmountNotification object:nil];
    
    return;
    
}
- (void)stop {
    running = NO;
    dataCollected = NO;
}

- (void) volumeListDidChange:(NSNotification *)notification {
    NSMutableDictionary *volumeList = [NSMutableDictionary dictionaryWithCapacity:0];
    
    NSArray *mountedVolumes = [[NSWorkspace sharedWorkspace] mountedLocalVolumePaths];
    
    for (NSString *mountedVolume in mountedVolumes) {
        [volumeList setValue:mountedVolume forKey:mountedVolume];
    }
    
    
    self.mountedVolumes = volumeList;

    if ([self.mountedVolumes count] > 0) {
        dataCollected = YES;
    }
    else {
        dataCollected = NO;
    }

}


- (NSString *)name {
    return @"MountedVolume";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule {
    __block BOOL found = NO;
    
    [self.mountedVolumes enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if ([key isEqualToString:[rule valueForKey:@"parameter"]]) {
            found = YES;
            *stop = YES;
        }
    }];
    
    return found;
}

- (NSString *)getSuggestionLeadText:(NSString *)type {
    return NSLocalizedString(@"The following volume is mounted", @"In rule-adding dialog");
}

- (NSArray *)getSuggestions {


    NSMutableArray *array = [NSMutableArray arrayWithCapacity:[self.mountedVolumes count]];
    
	[self.mountedVolumes enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		NSString *identifier = key;
		NSString *desc = key;
		[array addObject:
         [NSDictionary dictionaryWithObjectsAndKeys:
          [self name], @"type",
          identifier, @"parameter",
          desc, @"description", nil]];
        
    }];
	
    
	return array;
}

- (NSString *) friendlyName {
    return NSLocalizedString(@"Mounted Volume", @"");
}


@end
