//
//  AudioOutputEvidenceSource.h
//  ControlPlane
//
//  Created by David Symonds on 11/07/07.
//

#import <Cocoa/Cocoa.h>
#import <CoreAudio/CoreAudio.h>
#import "GenericEvidenceSource.h"


@interface AudioOutputEvidenceSource : GenericEvidenceSource {
	AudioDeviceID deviceID;
	UInt32 source;
}

- (id)init;

- (void)doRealUpdate;

- (void)start;
- (void)stop;

- (NSString *)name;
- (BOOL)doesRuleMatch:(NSDictionary *)rule;
- (NSString *)getSuggestionLeadText:(NSString *)type;
- (NSArray *)getSuggestions;

@end
