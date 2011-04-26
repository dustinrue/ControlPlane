/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Kent Sutherland
 *
 * Copyright (c) 2011 Andreas Linde & Kent Sutherland. All rights reserved.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import "QuincyDemoAppDelegate.h"

@implementation QuincyDemoAppDelegate

// set the main nibs window to hidden on startup
// this delegate method is required to be implemented!
- (void) showMainApplicationWindow {
	[window makeFirstResponder: nil];
	[window makeKeyAndOrderFront:nil];
}


- (void)applicationDidFinishLaunching:(NSNotification *)note {
	// Launch the crash reporter task
    
    // setSubmissionURL for self hosted Example: http://yourserver.com/crash_v200.php
    // setAppIdentifier for HockeyApp Example: 658b693ff4c164e65168fe0f43112ac0
    
    [[BWQuincyManager sharedQuincyManager] setCompanyName:@"My company"];
    [[BWQuincyManager sharedQuincyManager] setDelegate:self];
    [[BWQuincyManager sharedQuincyManager] setAppIdentifier:@"658b693ff4c164e65168fe0f43112ac0"];
}


- (void)bam {
	signal(SIGBUS, SIG_DFL);
	
	*(long*)0 = 0xDEADBEEF;
}


- (IBAction)doCrash:(id)sender {
	[self bam];
}

@end
