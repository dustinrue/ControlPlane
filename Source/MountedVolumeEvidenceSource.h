//
//  MountedVolumeEvidenceSource.h
//  ControlPlane
//
//  Created by Dustin Rue on 6/19/14.
//
//

#import "GenericEvidenceSource.h"

@interface MountedVolumeEvidenceSource : GenericEvidenceSource

@property (strong) NSDictionary *mountedVolumes;

@end
