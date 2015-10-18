//
//  AudioOutputEvidenceSource.h
//  ControlPlane
//
//  Created by David Symonds on 11/07/07.
//

#import "GenericEvidenceSource.h"
#import <CoreAudio/CoreAudio.h>


@interface AudioOutputEvidenceSource : GenericEvidenceSource {
	AudioDeviceID deviceID;
    AudioDeviceID builtinDeviceID;
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
