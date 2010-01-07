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

#import <CrashReporter/CrashReporter.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import "CrashReportSender.h"

#define USER_AGENT @"CrashReportSender/1.0"

@interface CrashReportSender ()

- (void)attemptCrashReportSubmission;
- (void)showCrashStatusMessage;

- (void)handleCrashReport;
- (void)_cleanCrashReports;
- (void)_sendCrashReports;

- (NSString *)_crashLogStringForReport:(PLCrashReport *)report;
- (void)_postXML:(NSString*)xml toURL:(NSURL*)url;
- (BOOL)_isSubmissionHostReachable;

- (BOOL)hasPendingCrashReport;
- (void)wentOnline:(NSNotification *)note;

@end

@implementation CrashReportSender

+ (CrashReportSender *)sharedCrashReportSender
{
	static CrashReportSender *crashReportSender = nil;
	
	if (crashReportSender == nil) {
		crashReportSender = [[CrashReportSender alloc] init];
	}
	
	return crashReportSender;
}

- (id) init
{
	self = [super init];

	if ( self != nil)
	{
		_serverResult = -1;
		_amountCrashes = 0;
		_crashIdenticalCurrentVersion = YES;
		_crashReportFeedbackActivated = NO;
		_delegate = nil;
		
		NSString *testValue = [[NSUserDefaults standardUserDefaults] stringForKey:kCrashReportAnalyzerStarted];
		if (testValue == nil)
		{
			_crashReportAnalyzerStarted = 0;		
		} else {
			_crashReportAnalyzerStarted = [[NSUserDefaults standardUserDefaults] integerForKey:kCrashReportAnalyzerStarted];
		}
		
		testValue = nil;
		testValue = [[NSUserDefaults standardUserDefaults] stringForKey:kCrashReportActivated];
		if (testValue == nil)
		{
			_crashReportActivated = YES;
			[[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:YES] forKey:kCrashReportActivated];
		} else {
			_crashReportActivated = [[NSUserDefaults standardUserDefaults] boolForKey:kCrashReportActivated];
		}
		
		if (_crashReportActivated)
		{
			_crashFiles = [[NSMutableArray alloc] init];
			NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
			_crashesDir = [[NSString stringWithFormat:@"%@", [[paths objectAtIndex:0] stringByAppendingPathComponent:@"/crashes/"]] retain];

			NSFileManager *fm = [NSFileManager defaultManager];
			
			if (![fm fileExistsAtPath:_crashesDir])
			{
				NSDictionary *attributes = [NSDictionary dictionaryWithObject: [NSNumber numberWithUnsignedLong: 0755] forKey: NSFilePosixPermissions];
				NSError *theError = NULL;
				
				[fm createDirectoryAtPath:_crashesDir withIntermediateDirectories: YES attributes: attributes error: &theError];
			}
			
			PLCrashReporter *crashReporter = [PLCrashReporter sharedReporter];
			NSError *error;

			// Check if we previously crashed
			if ([crashReporter hasPendingCrashReport])
				[self handleCrashReport];

			// Enable the Crash Reporter
			if (![crashReporter enableCrashReporterAndReturnError: &error])
				NSLog(@"Warning: Could not enable crash reporter: %@", error);
		}
	}
	return self;
}


- (void) dealloc
{
	[super dealloc];
	[_crashesDir release];
	[_crashFiles release];
	if (_submitTimer != nil)
	{
		[_submitTimer invalidate];
		[_submitTimer release];
	}
}


- (BOOL)hasPendingCrashReport
{
	if (_crashReportActivated)
	{
		NSFileManager *fm = [NSFileManager defaultManager];
		
		if ([_crashFiles count] == 0 && [fm fileExistsAtPath:_crashesDir])
		{
			NSString *file;

			NSDirectoryEnumerator *dirEnum = [fm enumeratorAtPath: _crashesDir];
			
			while (file = [dirEnum nextObject])
			{
				NSDictionary *fileAttributes = [fm fileAttributesAtPath:[_crashesDir stringByAppendingPathComponent:file] traverseLink:YES];
				if ([[fileAttributes objectForKey:NSFileSize] intValue] > 0)
				{
					[_crashFiles addObject:file];
				}
			}
		}
		
		if ([_crashFiles count] > 0)
		{
			_amountCrashes = [_crashFiles count];
			return YES;
		}
		else
			return NO;
	} else
		return NO;
}

- (void)sendCrashReportToURL:(NSURL *)submissionURL delegate:(id)delegate activateFeedback:(BOOL)activateFeedback;
{
    if ([self hasPendingCrashReport])
    {
        [_submissionURL autorelease];
        _submissionURL = [submissionURL copy];
        
        _crashReportFeedbackActivated = activateFeedback;
        _delegate = delegate;
        
        if (_submitTimer == nil) {
            _submitTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(attemptCrashReportSubmission) userInfo:nil repeats:NO];
        }
    }
}

- (void)registerOnline
{
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(wentOnline:)
												 name:@"kNetworkReachabilityChangedNotification"
											   object:nil];            
}

- (void)unregisterOnline
{
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:@"kNetworkReachabilityChangedNotification"
												  object:nil];
}

- (void)wentOnline:(NSNotification *)note
{
	[self unregisterOnline];
	[self attemptCrashReportSubmission];
}

- (void)attemptCrashReportSubmission
{
	_submitTimer = nil;
	
	if (![self _isSubmissionHostReachable]) {
		[self registerOnline];
	} else if ([self hasPendingCrashReport]) {
		[self unregisterOnline];
        
		if (![[NSUserDefaults standardUserDefaults] boolForKey: kAutomaticallySendCrashReports]) {
			UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"CrashDataFoundTitle", @"Title showing in the alert box when crash report data has been found")
																message:NSLocalizedString(@"CrashDataFoundDescription", @"Description explaining that crash data has been found and ask the user if the data might be uplaoded to the developers server")
															   delegate:self
													  cancelButtonTitle:NSLocalizedString(@"No", @"")
													  otherButtonTitles:NSLocalizedString(@"Yes", @""), NSLocalizedString(@"Always", @""), nil];

			[alertView setTag: CrashAlertTypeSend];
			[alertView show];
			[alertView release];
		} else {
			[self _sendCrashReports];
		}
	}
}


- (void) showCrashStatusMessage
{
	UIAlertView *alertView;
	
	_amountCrashes--;
	if (_crashReportFeedbackActivated && _amountCrashes == 0 && _serverResult >= CrashReportStatusAssigned && _crashIdenticalCurrentVersion)
	{
		// show some feedback to the user about the crash status
		
		switch (_serverResult) {
			case CrashReportStatusAssigned:
				alertView = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"CrashResponseTitle", @"Title for the alertview giving feedback about the crash")
													   message: NSLocalizedString(@"CrashResponseNextRelease", @"Full text telling the bug is fixed and will be available in an upcoming release")
													  delegate: self
											 cancelButtonTitle: NSLocalizedString(@"Ok", @"")
											 otherButtonTitles: nil];
				break;
			case CrashReportStatusSubmitted:
				alertView = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"CrashResponseTitle", @"Title for the alertview giving feedback about the crash")
													   message: NSLocalizedString(@"CrashResponseWaitingApple", @"Full text telling the bug is fixed and the new release is waiting at Apple for approval")
													  delegate: self
											 cancelButtonTitle: NSLocalizedString(@"Ok", @"")
											 otherButtonTitles: nil];
				break;
			case CrashReportStatusAvailable:
				alertView = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"CrashResponseTitle", @"Title for the alertview giving feedback about the crash")
													   message: NSLocalizedString(@"CrashResponseAvailable", @"Full text telling the bug is fixed and an update is available in the AppStore for download")
													  delegate: self
											 cancelButtonTitle: NSLocalizedString(@"Ok", @"")
											 otherButtonTitles: nil];
				break;
			default:
				alertView = nil;
				break;
		}
		
		if (alertView != nil)
		{
			[alertView setTag: CrashAlertTypeFeedback];
			[alertView show];
			[alertView release];
		}
	}
}


#pragma mark -
#pragma mark UIAlertView Delegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if ([alertView tag] == CrashAlertTypeSend)
	{
		switch (buttonIndex) {
			case 0:
				[self _cleanCrashReports];
				break;
			case 1:
				[self _sendCrashReports];
				break;
			case 2:
				[[NSUserDefaults standardUserDefaults] setBool:YES forKey:kAutomaticallySendCrashReports];
				
				[self _sendCrashReports];
				break;
		}
	}
}

#pragma mark -
#pragma mark NSXMLParser Delegate

#pragma mark NSXMLParser

- (void)parseXMLFileAtURL:(NSString *)url parseError:(NSError **)error
{	
	NSXMLParser *parser = [[NSXMLParser alloc] initWithContentsOfURL:[NSURL URLWithString:url]];
	// Set self as the delegate of the parser so that it will receive the parser delegate methods callbacks.
	[parser setDelegate:self];
	// Depending on the XML document you're parsing, you may want to enable these features of NSXMLParser.
	[parser setShouldProcessNamespaces:NO];
	[parser setShouldReportNamespacePrefixes:NO];
	[parser setShouldResolveExternalEntities:NO];
	
	[parser parse];
	
	NSError *parseError = [parser parserError];
	if (parseError && error) {
		*error = parseError;
	}
	
	[parser release];
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
	if (qName)
	{
		elementName = qName;
	}
	
	if ([elementName isEqualToString:@"result"]) {
		_contentOfProperty = [NSMutableString string];
	}
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{     
	if (qName)
	{
		elementName = qName;
	}
	
	if ([elementName isEqualToString: @"result"]) {
		if ([_contentOfProperty intValue] > _serverResult) {
			_serverResult = [_contentOfProperty intValue];
		} else {
            CrashReportStatus errorcode = [_contentOfProperty intValue];
            NSLog(@"CrashReporter ended in error code: %i", errorcode);
        }
	}
}


- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
	if (_contentOfProperty)
	{
		// If the current element is one whose content we care about, append 'string'
		// to the property that holds the content of the current element.
		if (string != nil)
		{
			[_contentOfProperty appendString:string];
		}
	}
}

#pragma mark -
#pragma mark Private

- (void)_cleanCrashReports
{
	NSError *error;
	
	NSFileManager *fm = [NSFileManager defaultManager];
	
	for (int i=0; i < [_crashFiles count]; i++)
	{		
		[fm removeItemAtPath:[_crashesDir stringByAppendingPathComponent:[_crashFiles objectAtIndex:i]] error:&error];
	}
	[_crashFiles removeAllObjects];	
}

- (void)_sendCrashReports
{
	NSError *error;
		
	NSString *userid = @"";
	NSString *contact = @"";
	NSString *description = @"";
	
	if (_delegate != nil && [_delegate respondsToSelector:@selector(crashReportUserID)])
	{
		userid = [_delegate crashReportUserID];
	}

	if (_delegate != nil && [_delegate respondsToSelector:@selector(crashReportContact)])
	{
		contact = [_delegate crashReportContact];
	}

	if (_delegate != nil && [_delegate respondsToSelector:@selector(crashReportDescription)])
	{
		description = [_delegate crashReportDescription];
	}
	

	for (int i=0; i < [_crashFiles count]; i++)
	{
		NSString *filename = [_crashesDir stringByAppendingPathComponent:[_crashFiles objectAtIndex:i]];
		NSData *crashData = [NSData dataWithContentsOfFile:filename];
		
		if ([crashData length] > 0)
		{
			PLCrashReport *report = [[[PLCrashReport alloc] initWithData:crashData error:&error] autorelease];
			
			NSString *crashLogString = [self _crashLogStringForReport:report];
			
			if ([report.applicationInfo.applicationVersion compare:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]] != NSOrderedSame)
			{
				_crashIdenticalCurrentVersion = NO;
			}
			
			NSString *xml = [NSString stringWithFormat:@"<crash><applicationname>%s</applicationname><bundleidentifier>%@</bundleidentifier><systemversion>%@</systemversion><senderversion>%@</senderversion><version>%@</version><userid>%@</userid><contact>%@</contact><description>%@</description><log><![CDATA[%@]]></log></crash>",
							 [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"] UTF8String],
							 report.applicationInfo.applicationIdentifier,
							 [[UIDevice currentDevice] systemVersion],
							 [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],
							 report.applicationInfo.applicationVersion,
							 userid,
							 contact,
							 description,
							 crashLogString];
			
			[self _postXML:xml toURL:_submissionURL];
		}
	}
	
	[self _cleanCrashReports];
}


- (NSString *)_crashLogStringForReport:(PLCrashReport *)report
{
	NSMutableString *xmlString = [NSMutableString string];
	
	/* Header */
	
	/* Map to apple style OS nane */
	const char *osName;
	switch (report.systemInfo.operatingSystem) {
		case PLCrashReportOperatingSystemiPhoneOS:
			osName = "iPhone OS";
			break;
		case PLCrashReportOperatingSystemiPhoneSimulator:
			osName = "Mac OS X";
			break;
		default:
			osName = "iPhone OS";
			break;
	}
	
	/* Map to Apple-style code type */
	const char *codeType;
	switch (report.systemInfo.architecture) {
		case PLCrashReportArchitectureARM:
			codeType = "ARM";
			break;
		default:
			codeType = "ARM";
			break;
	}
	
	[xmlString appendString:@"Incident Identifier: [TODO]\n"];
	[xmlString appendString:@"CrashReporter Key:   [TODO]\n"];
	[xmlString appendString:@"Process:         [TODO]\n"];
	[xmlString appendString:@"Path:            [TODO]\n"];
	[xmlString appendFormat:@"Identifier:      %s\n", [report.applicationInfo.applicationIdentifier UTF8String]];
	[xmlString appendFormat:@"Version:         %s\n", [report.applicationInfo.applicationVersion UTF8String]];
	[xmlString appendFormat:@"Code Type:       %s\n", codeType];
	[xmlString appendString:@"Parent Process:  [TODO]\n"];
	
	[xmlString appendString:@"\n"];
	
	/* System info */
	[xmlString appendFormat:@"Date/Time:       %s\n", [[report.systemInfo.timestamp description] UTF8String]];
	[xmlString appendFormat:@"OS Version:      %s %s\n", osName, [report.systemInfo.operatingSystemVersion UTF8String]];
	[xmlString appendString:@"Report Version:  103\n"];
	
	[xmlString appendString:@"\n"];
	
	/* Exception code */
	[xmlString appendFormat:@"Exception Type:  %s\n", [report.signalInfo.name UTF8String]];
	[xmlString appendFormat:@"Exception Codes: %s at 0x%" PRIx64 "\n", [report.signalInfo.code UTF8String], report.signalInfo.address];
	
	for (PLCrashReportThreadInfo *thread in report.threads) {
		if (thread.crashed) {
			[xmlString appendFormat:@"Crashed Thread:  %d\n", thread.threadNumber];
			break;
		}
	}
	
	[xmlString appendString:@"\n"];
	
    if (report.hasExceptionInfo) {
        [xmlString appendString:@"Application Specific Information:\n"];
        [xmlString appendFormat: @"*** Terminating app due to uncaught exception '%@', reason: '%@'", report.exceptionInfo.exceptionName, report.exceptionInfo.exceptionReason];
        [xmlString appendString:@"\n\n"];
    }
    
	/* Threads */
	for (PLCrashReportThreadInfo *thread in report.threads) {
		if (thread.crashed)
			[xmlString appendFormat:@"Thread %d Crashed:\n", thread.threadNumber];
		else
			[xmlString appendFormat:@"Thread %d:\n", thread.threadNumber];
		for (NSUInteger frame_idx = 0; frame_idx < [thread.stackFrames count]; frame_idx++) {
			PLCrashReportStackFrameInfo *frameInfo = [thread.stackFrames objectAtIndex: frame_idx];
			PLCrashReportBinaryImageInfo *imageInfo;
			
			/* Base image address containing instrumention pointer, offset of the IP from that base
			 * address, and the associated image name */
			uint64_t baseAddress = 0x0;
			uint64_t pcOffset = 0x0;
			const char *imageName = "\?\?\?";
			
			imageInfo = [report imageForAddress: frameInfo.instructionPointer];
			if (imageInfo != nil) {
				imageName = [[imageInfo.imageName lastPathComponent] UTF8String];
				baseAddress = imageInfo.imageBaseAddress;
				pcOffset = frameInfo.instructionPointer - imageInfo.imageBaseAddress;
			}
			
			[xmlString appendFormat:@"%-4d%-36s0x%08" PRIx64 " 0x%" PRIx64 " + %" PRId64 "\n", 
						 frame_idx, imageName, frameInfo.instructionPointer, baseAddress, pcOffset];
		}
		[xmlString appendString:@"\n"];
	}
	
	/* Images */
	[xmlString appendFormat:@"Binary Images:\n"];
	for (PLCrashReportBinaryImageInfo *imageInfo in report.images) {
		NSString *uuid;
		/* Fetch the UUID if it exists */
		if (imageInfo.hasImageUUID)
			uuid = imageInfo.imageUUID;
		else
			uuid = @"???";
		
		/* base_address - terminating_address file_name identifier (<version>) <uuid> file_path */
		[xmlString appendFormat:@"0x%" PRIx64 " - 0x%" PRIx64 "  %s \?\?\? (\?\?\?) <%s> %s\n",
					 imageInfo.imageBaseAddress,
					 imageInfo.imageBaseAddress + imageInfo.imageSize,
					 [[imageInfo.imageName lastPathComponent] UTF8String],
					 [uuid UTF8String],
					 [imageInfo.imageName UTF8String]];
	}
	
finish:	
	return xmlString;
}

- (void)_postXML:(NSString*)xml toURL:(NSURL*)url
{
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
	NSString *boundary = @"----FOO";
	
	[request setCachePolicy: NSURLRequestReloadIgnoringLocalCacheData];
	[request setValue:USER_AGENT forHTTPHeaderField:@"User-Agent"];
	[request setTimeoutInterval: 15];
	[request setHTTPMethod:@"POST"];
	NSString *contentType = [NSString stringWithFormat:@"multipart/form-data, boundary=%@", boundary];
	[request setValue:contentType forHTTPHeaderField:@"Content-type"];
	
	NSMutableData *postBody =  [NSMutableData data];
	[postBody appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
	[postBody appendData:[@"Content-Disposition: form-data; name=\"xmlstring\"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
	[postBody appendData:[xml dataUsingEncoding:NSUTF8StringEncoding]];
	[postBody appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
	[request setHTTPBody:postBody];
	
	_serverResult = CrashReportStatusUnknown;
	_statusCode = 200;
	
	//Release when done in the delegate method
	_responseData = [[NSMutableData alloc] init];
	
	if (_delegate != nil && [_delegate respondsToSelector:@selector(connectionOpened)])
	{
		[_delegate connectionOpened];
	}
	
	[[NSURLConnection connectionWithRequest:request delegate:self] retain];
}

#pragma mark NSURLConnection Delegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
		_statusCode = [(NSHTTPURLResponse *)response statusCode];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[_responseData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	[_responseData release];
	_responseData = nil;
	[connection autorelease];

	if (_delegate != nil && [_delegate respondsToSelector:@selector(connectionClosed)])
	{
		[_delegate connectionClosed];
	}
	
	[self showCrashStatusMessage];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{	
	if (_statusCode >= 200 && _statusCode < 400)
	{
		NSXMLParser *parser = [[NSXMLParser alloc] initWithData:_responseData];
		// Set self as the delegate of the parser so that it will receive the parser delegate methods callbacks.
		[parser setDelegate:self];
		// Depending on the XML document you're parsing, you may want to enable these features of NSXMLParser.
		[parser setShouldProcessNamespaces:NO];
		[parser setShouldReportNamespacePrefixes:NO];
		[parser setShouldResolveExternalEntities:NO];
		
		[parser parse];
		
		[parser release];
	}
	
	[_responseData release];
	_responseData = nil;
	[connection autorelease];

	if (_delegate != nil && [_delegate respondsToSelector:@selector(connectionClosed)])
	{
		[_delegate connectionClosed];
	}
	
	[self showCrashStatusMessage];
}

#pragma mark PLCrashReporter

//
// Called to handle a pending crash report.
//
- (void) handleCrashReport
{
	PLCrashReporter *crashReporter = [PLCrashReporter sharedReporter];
	NSError *error;
	
	// Try loading the crash report
	NSData *crashData = [NSData dataWithData:[crashReporter loadPendingCrashReportDataAndReturnError: &error]];
	
	NSString *cacheFilename = [NSString stringWithFormat: @"%.0f", [NSDate timeIntervalSinceReferenceDate]];
	
	if (crashData == nil) {
		NSLog(@"Could not load crash report: %@", error);
		goto finish;
	} else {
		[crashData writeToFile:[_crashesDir stringByAppendingPathComponent: cacheFilename] atomically:YES];
	}
	
	// check if the next call ran successfully the last time
	if (_crashReportAnalyzerStarted == 0)
	{
		// mark the start of the routine
		_crashReportAnalyzerStarted = 1;
		[[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithInt:_crashReportAnalyzerStarted] forKey:kCrashReportAnalyzerStarted];
		
		// We could send the report from here, but we'll just print out
		// some debugging info instead
		PLCrashReport *report = [[[PLCrashReport alloc] initWithData: [crashData retain] error: &error] autorelease];
		if (report == nil) {
			NSLog(@"Could not parse crash report");
			goto finish;
		}
	}
		
	// Purge the report
finish:
	// mark the end of the routine
	_crashReportAnalyzerStarted = 0;
	[[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithInt:_crashReportAnalyzerStarted] forKey:kCrashReportAnalyzerStarted];
		
	[crashReporter purgePendingCrashReport];
	return;
}

#pragma mark Reachability
		
- (BOOL)_isSubmissionHostReachable
{
	SCNetworkReachabilityFlags flags;
    SCNetworkReachabilityRef reachabilityRef = nil;
    
    if (![_submissionURL host] || ![[_submissionURL host] length]) {
		return NO;
	}
    
    reachabilityRef = SCNetworkReachabilityCreateWithName(NULL, [[_submissionURL host] UTF8String]);
    
	if (!reachabilityRef) {
		return NO;
	}
    
	BOOL gotFlags = SCNetworkReachabilityGetFlags(reachabilityRef, &flags);
    
    if (reachabilityRef != nil)
		CFRelease(reachabilityRef);
    
	return gotFlags && flags & kSCNetworkReachabilityFlagsReachable && (flags & kSCNetworkReachabilityFlagsIsWWAN || !(flags & kSCNetworkReachabilityFlagsConnectionRequired));
}

@end
