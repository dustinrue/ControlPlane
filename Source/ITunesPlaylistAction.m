//
//	ITunesPlaylistAction.m
//	ControlPlane
//
//	Created by David Jennes on 03/09/11.
//	Copyright 2011. All rights reserved.
//

#import "ITunesPlaylistAction.h"
#import <ScriptingBridge/ScriptingBridge.h>
#import "iTunes.h"
#import "DSLogger.h"

@implementation ITunesPlaylistAction

- (id) init {
	self = [super init];
	if (!self)
		return nil;
	
	playlist = [[NSString alloc] init];
	
	return self;
}

- (id) initWithDictionary: (NSDictionary *) dict {
	self = [super initWithDictionary: dict];
	if (!self)
		return nil;
	
	playlist = [[dict valueForKey: @"parameter"] copy];
	
	return self;
}

- (id) initWithOption: (NSString *) option {
	self = [super init];
	if (!self)
		return nil;
	
	playlist = [option copy];
	
	return self;
}

- (void) dealloc {
	[playlist release];
	[super dealloc];
}

- (NSMutableDictionary *) dictionary {
	NSMutableDictionary *dict = [super dictionary];
	
	[dict setObject: [[playlist copy] autorelease] forKey: @"parameter"];
	
	return dict;
}

- (NSString *) description {
	return [NSString stringWithFormat: NSLocalizedString(@"Playing '%@'", @""), playlist];
}

- (BOOL) execute: (NSString **) errorString {
	@try {
		iTunesApplication *iTunes = [SBApplication applicationWithBundleIdentifier: @"com.apple.iTunes"];
		
		// find library
		iTunesSource *library = [iTunes.sources objectWithName: @"Library"];
		
		// find playlist
		iTunesPlaylist *p = [library.playlists objectWithName: playlist];
		
		// play random track
		[p playOnce: false];
	} @catch (NSException *e) {
		DSLog(@"Exception: %@", e);
		*errorString = NSLocalizedString(@"Couldn't play playlist!", @"In ITunesPlaylistAction");
		return NO;
	}
	
	return YES;
}

+ (NSString *) helpText {
	return NSLocalizedString(@"The parameter for iTunesPlaylist actions is the name of "
							 "the playlist to be played in iTunes.", @"");
}

+ (NSString *) creationHelpText {
	return NSLocalizedString(@"Play in iTunes (playlist):", @"");
}

+ (NSArray *) limitedOptions {
	NSMutableArray *options = nil;
	
	@try {
		iTunesApplication *iTunes = [SBApplication applicationWithBundleIdentifier: @"com.apple.iTunes"];
		
		// find library
		iTunesSource *library = [iTunes.sources objectWithName: @"Library"];
		SBElementArray *playlists = library.userPlaylists;
		options = [NSMutableArray arrayWithCapacity: playlists.count];
		
		// for each playlist
		for (iTunesPlaylist *item in playlists)
			[options addObject:[NSDictionary dictionaryWithObjectsAndKeys:
								item.name, @"option", item.name, @"description", nil]];
		
	} @catch (NSException *e) {
		DSLog(@"Exception: %@", e);
		options = [NSArray array];
	}
	
	return options;
}

+ (NSString *) friendlyName {
    return NSLocalizedString(@"Play iTunes Playlist", @"");
}

+ (NSString *)menuCategory {
    return NSLocalizedString(@"Sound and Music", @"");
}

@end
