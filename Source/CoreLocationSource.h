//
//	CoreLocationSource.h
//	ControlPlane
//
//	Created by David Jennes on 03/09/11.
//  Copyright 2011. All rights reserved.
//
//  Code rework and improvements by Vladimir Beloborodov (VladimirTechMan) on 1 September 2013.
//

#import "EvidenceSource.h"
#import <CoreLocation/CoreLocation.h>
#import <WebKit/WebKit.h>

@interface CoreLocationSource : EvidenceSource <CLLocationManagerDelegate>

- (id)init;
- (void)dealloc;
- (void)start;
- (void)stop;

- (NSMutableDictionary *)readFromPanel;
- (void)writeToPanel:(NSDictionary *)dict usingType:(NSString *)type;
- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;

- (IBAction)showCoreLocation:(id)sender;
- (BOOL)validateAddress:(inout NSString **)newValue error:(out NSError **)outError;
- (BOOL)validateCoordinates:(inout NSString **)newValue error:(out NSError **)outError;

@end
