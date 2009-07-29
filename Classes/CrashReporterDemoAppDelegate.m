/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Kent Sutherland
 *
 * Copyright (c) 2009 Andreas Linde & Kent Sutherland. All rights reserved.
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

#import "CrashReporterDemoAppDelegate.h"
#import "CrashReporterDemoViewController.h"
#import "CrashReportSender.h"

#define CRASH_REPORTER_URL [NSURL URLWithString:@"http:/your.server.com/crash_v200.php"]

@implementation CrashReporterDemoAppDelegate

@synthesize window;
@synthesize viewController;

- (void)applicationDidFinishLaunching:(UIApplication *)application
{	
	_application = application;
	
	// Override point for customization after app launch    
	[window addSubview:viewController.view];
	[window makeKeyAndVisible];
  
  if ([[CrashReportSender sharedCrashReportSender] hasPendingCrashReport]) {
	  [[CrashReportSender sharedCrashReportSender] scheduleCrashReportSubmissionToURL:CRASH_REPORTER_URL delegate:self activateFeedback:YES];
	}  
}


- (void)dealloc {
	[viewController release];
	[window release];
	[super dealloc];
}


#pragma mark CrashReportSenderDelegate

-(void)connectionOpened
{
	_application.networkActivityIndicatorVisible = YES;
}


-(void)connectionClosed
{
	_application.networkActivityIndicatorVisible = NO;
}


@end