//
//  ContextEvidenceSource.h
//  ControlPlane
//
//  Created by Dustin Rue on 4/15/14.
//
//

#import "GenericEvidenceSource.h"

@interface ContextEvidenceSource : GenericEvidenceSource

@property (strong) NSArray *activeContexts;

@end
