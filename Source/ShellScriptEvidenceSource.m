//
//  ShellScriptEvidenceSource.m
//  ControlPlane
//
//  Created by Dustin Rue 8/5/2011.
//
// This evidence source allows the end user to create
// their own custom evidence source using an external program,
// or script.  Anything can be used so long as it returns 0
// for false and 1 for true.

#import "ShellScriptEvidenceSource.h"
#import "DSLogger.h"


@interface ShellScriptEvidenceSource (Private)

- (void) fileBrowseSheetFinished:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

@end


@implementation ShellScriptEvidenceSource
@synthesize currentFileName;




- (id)init {
    self = [super initWithNibNamed:@"ShellScriptRule"];
    if (!self)
        return nil;
    
    running = NO;
    [self setDataCollected: NO];

    
	return self;
}

- (void)awakeFromNib {
    [self setCurrentFileName:@"Please browse for a shell script"];
}


- (void)dealloc {

	[super dealloc];
}

- (void)start {
    running = YES;
    [self setDataCollected:true];
	
}

- (void)stop {    
    running = NO;
}


- (void)doUpdate {
}

- (NSString *)name {
	return @"ShellScript";
}

- (BOOL)doesRuleMatch:(NSDictionary *)rule {
    
	NSMutableArray *args = [[NSMutableArray alloc] initWithCapacity:1];
    
	[args insertObject:[rule objectForKey:@"parameter"] atIndex:0];
    
    DSLog(@"attempting to run %@", [args objectAtIndex:0]);
    
	NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/bin/sh" arguments:args];
    
	[task waitUntilExit];
    DSLog(@"task ended");

	if ([task terminationStatus] != 0) {
	    [args release];

		return NO;
	}
    	[args release];
	return YES;
}

- (NSMutableDictionary *)readFromPanel {
    NSMutableDictionary *dict = [super readFromPanel];
	
	// store values
	[dict setValue: currentFileName forKey: @"parameter"];
    [dict setValue: currentFileName forKey: @"description"];
    [dict setValue: @"ShellScript" forKey: @"type"];
	
	return dict;
}

- (void)writeToPanel:(NSDictionary *)dict usingType:(NSString *)type {
	[super writeToPanel: dict usingType: type];
	

	// show values
    [self setCurrentFileName:[dict objectForKey:@"parameter"]];

   
}


- (void)clearCollectedData {
    
}

- (IBAction) browseForScript:(id) sendor {
    NSOpenPanel *fileBrowser = [NSOpenPanel openPanel];
    
    [fileBrowser setCanChooseFiles:YES];
    [fileBrowser setCanChooseDirectories:NO];
    
    if ([fileBrowser runModal] == NSOKButton) {
        [self setCurrentFileName:[fileBrowser filename]];
    }
        
 
}

- (void) fileBrowseSheetFinished:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
        
}


@end
