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

#include <sys/sysctl.h>

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
- (NSString *)_getDevicePlatform;

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
		_crashData = nil;
        _urlConnection = nil;
        
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
    [_urlConnection cancel];
    [_urlConnection release]; 
    _urlConnection = nil;
    [_crashData release];
    
	[_crashesDir release];
	[_crashFiles release];
	if (_submitTimer != nil)
	{
		[_submitTimer invalidate];
		[_submitTimer release];
	}
	[super dealloc];
}


- (BOOL)hasPendingCrashReport
{
	if (_crashReportActivated)
	{
		NSFileManager *fm = [NSFileManager defaultManager];
		
		if ([_crashFiles count] == 0 && [fm fileExistsAtPath:_crashesDir])
		{
			NSString *file;
            NSError *error = nil;
            
			NSDirectoryEnumerator *dirEnum = [fm enumeratorAtPath: _crashesDir];
			
			while ((file = [dirEnum nextObject]))
			{
				NSDictionary *fileAttributes = [fm attributesOfItemAtPath:[_crashesDir stringByAppendingPathComponent:file] error:&error];
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

- (void)sendCrashReportToURL:(NSURL *)submissionURL delegate:(id <CrashReportSenderDelegate>)delegate activateFeedback:(BOOL)activateFeedback;
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
			UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedStringFromTable(@"CrashDataFoundTitle", @"CrashReporter", @"Title showing in the alert box when crash report data has been found")
																message:NSLocalizedStringFromTable(@"CrashDataFoundDescription", @"CrashReporter", @"Description explaining that crash data has been found and ask the user if the data might be uplaoded to the developers server")
															   delegate:self
													  cancelButtonTitle:NSLocalizedStringFromTable(@"No", @"CrashReporter", @"")
													  otherButtonTitles:NSLocalizedStringFromTable(@"Yes", @"CrashReporter", @""), NSLocalizedStringFromTable(@"Always", @"CrashReporter", @""), nil];
			
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
		NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
		switch (_serverResult) {
			case CrashReportStatusAssigned:
				alertView = [[UIAlertView alloc] initWithTitle: NSLocalizedStringFromTable(@"CrashResponseTitle", @"CrashReporter", @"Title for the alertview giving feedback about the crash")
													   message:[NSString stringWithFormat:NSLocalizedStringFromTable(@"CrashResponseNextRelease", @"CrashReporter", @"Full text telling the bug is fixed and will be available in an upcoming release"), appName]
													  delegate: self
											 cancelButtonTitle: NSLocalizedStringFromTable(@"OK", @"CrashReporter", @"")
											 otherButtonTitles: nil];
				break;
			case CrashReportStatusSubmitted:
				alertView = [[UIAlertView alloc] initWithTitle: NSLocalizedStringFromTable(@"CrashResponseTitle", @"CrashReporter", @"Title for the alertview giving feedback about the crash")
													   message: [NSString stringWithFormat:NSLocalizedStringFromTable(@"CrashResponseWaitingApple", @"CrashReporter", @"Full text telling the bug is fixed and the new release is waiting at Apple for approval"), appName]
													  delegate: self
											 cancelButtonTitle: NSLocalizedStringFromTable(@"OK", @"CrashReporter", @"")
											 otherButtonTitles: nil];
				break;
			case CrashReportStatusAvailable:
				alertView = [[UIAlertView alloc] initWithTitle: NSLocalizedStringFromTable(@"CrashResponseTitle", @"CrashReporter", @"Title for the alertview giving feedback about the crash")
													   message: [NSString stringWithFormat:NSLocalizedStringFromTable(@"CrashResponseAvailable", @"CrashReporter", @"Full text telling the bug is fixed and an update is available in the AppStore for download"), appName]
													  delegate: self
											 cancelButtonTitle: NSLocalizedStringFromTable(@"OK", @"CrashReporter", @"")
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

- (BOOL)parseXMLFileAtURL:(NSString *)url parseError:(NSError **)error
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
    
    return (parseError) ? YES : NO;
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


- (NSString *)_getDevicePlatform
{
	size_t size;
	sysctlbyname("hw.machine", NULL, &size, NULL, 0);
	char *answer = malloc(size);
	sysctlbyname("hw.machine", answer, &size, NULL, 0);
	NSString *platform = [NSString stringWithCString:answer encoding: NSUTF8StringEncoding];
	free(answer);
	return platform;
}

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
			
			NSString *xml = [NSString stringWithFormat:@"<crash><applicationname>%s</applicationname><bundleidentifier>%@</bundleidentifier><systemversion>%@</systemversion><platform>%@</platform><senderversion>%@</senderversion><version>%@</version><userid>%@</userid><contact>%@</contact><description><![CDATA[%@]]></description><log><![CDATA[%@]]></log></crash>",
							 [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"] UTF8String],
							 report.applicationInfo.applicationIdentifier,
							 [[UIDevice currentDevice] systemVersion],
							 [self _getDevicePlatform],
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
    boolean_t lp64;
	
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
	NSString *codeType;
	switch (report.systemInfo.architecture) {
		case PLCrashReportArchitectureARM:
			codeType = @"ARM (Native)";
            lp64 = false;
			break;
        case PLCrashReportArchitectureX86_32:
            codeType = @"X86";
            lp64 = false;
            break;
        case PLCrashReportArchitectureX86_64:
            codeType = @"X86-64";
            lp64 = true;
            break;
        case PLCrashReportArchitecturePPC:
            codeType = @"PPC";
            lp64 = false;
            break;
		default:
			codeType = @"ARM (Native)";
            lp64 = false;
			break;
	}
	
	[xmlString appendString:@"Incident Identifier: [TODO]\n"];
	[xmlString appendString:@"CrashReporter Key:   [TODO]\n"];
    
    /* Application and process info */
    {
        NSString *unknownString = @"???";
        
        NSString *processName = unknownString;
        NSString *processId = unknownString;
        NSString *processPath = unknownString;
        NSString *parentProcessName = unknownString;
        NSString *parentProcessId = unknownString;
        
        /* Process information was not available in earlier crash report versions */
        if (report.hasProcessInfo) {
            /* Process Name */
            if (report.processInfo.processName != nil)
                processName = report.processInfo.processName;
            
            /* PID */
            processId = [[NSNumber numberWithUnsignedInteger: report.processInfo.processID] stringValue];
            
            /* Process Path */
            if (report.processInfo.processPath != nil)
                processPath = report.processInfo.processPath;
            
            /* Parent Process Name */
            if (report.processInfo.parentProcessName != nil)
                parentProcessName = report.processInfo.parentProcessName;
            
            /* Parent Process ID */
            parentProcessId = [[NSNumber numberWithUnsignedInteger: report.processInfo.parentProcessID] stringValue];
        }
        
        [xmlString appendFormat: @"Process:         %@ [%@]\n", processName, processId];
        [xmlString appendFormat: @"Path:            %@\n", processPath];
        [xmlString appendFormat: @"Identifier:      %@\n", report.applicationInfo.applicationIdentifier];
        [xmlString appendFormat: @"Version:         %@\n", report.applicationInfo.applicationVersion];
        [xmlString appendFormat: @"Code Type:       %@\n", codeType];
        [xmlString appendFormat: @"Parent Process:  %@ [%@]\n", parentProcessName, parentProcessId];
    }
    
	[xmlString appendString:@"\n"];
	
	/* System info */
	[xmlString appendFormat:@"Date/Time:       %s\n", [[report.systemInfo.timestamp description] UTF8String]];
	[xmlString appendFormat:@"OS Version:      %s %s\n", osName, [report.systemInfo.operatingSystemVersion UTF8String]];
	[xmlString appendString:@"Report Version:  104\n"];
	
	[xmlString appendString:@"\n"];
	
	/* Exception code */
	[xmlString appendFormat:@"Exception Type:  %s\n", [report.signalInfo.name UTF8String]];
    [xmlString appendFormat:@"Exception Codes: %@ at 0x%" PRIx64 "\n", report.signalInfo.code, report.signalInfo.address];
	
    for (PLCrashReportThreadInfo *thread in report.threads) {
        if (thread.crashed) {
            [xmlString appendFormat: @"Crashed Thread:  %ld\n", (long) thread.threadNumber];
            break;
        }
    }
	
	[xmlString appendString:@"\n"];
	
    if (report.hasExceptionInfo) {
        [xmlString appendString:@"Application Specific Information:\n"];
        [xmlString appendFormat: @"*** Terminating app due to uncaught exception '%@', reason: '%@'\n",
         report.exceptionInfo.exceptionName, report.exceptionInfo.exceptionReason];
        [xmlString appendString:@"\n"];
    }
    
	/* Threads */
    PLCrashReportThreadInfo *crashed_thread = nil;
    for (PLCrashReportThreadInfo *thread in report.threads) {
        if (thread.crashed) {
            [xmlString appendFormat: @"Thread %ld Crashed:\n", (long) thread.threadNumber];
            crashed_thread = thread;
        } else {
            [xmlString appendFormat: @"Thread %ld:\n", (long) thread.threadNumber];
        }
        for (NSUInteger frame_idx = 0; frame_idx < [thread.stackFrames count]; frame_idx++) {
            PLCrashReportStackFrameInfo *frameInfo = [thread.stackFrames objectAtIndex: frame_idx];
            PLCrashReportBinaryImageInfo *imageInfo;
            
            /* Base image address containing instrumention pointer, offset of the IP from that base
             * address, and the associated image name */
            uint64_t baseAddress = 0x0;
            uint64_t pcOffset = 0x0;
            NSString *imageName = @"\?\?\?";
            
            imageInfo = [report imageForAddress: frameInfo.instructionPointer];
            if (imageInfo != nil) {
                imageName = [imageInfo.imageName lastPathComponent];
                baseAddress = imageInfo.imageBaseAddress;
                pcOffset = frameInfo.instructionPointer - imageInfo.imageBaseAddress;
            }
            
            [xmlString appendFormat: @"%-4ld%-36s0x%08" PRIx64 " 0x%" PRIx64 " + %" PRId64 "\n", 
             (long) frame_idx, [imageName UTF8String], frameInfo.instructionPointer, baseAddress, pcOffset];
        }
        [xmlString appendString: @"\n"];
    }
    
    /* Registers */
    if (crashed_thread != nil) {
        [xmlString appendFormat: @"Thread %ld crashed with %@ Thread State:\n", (long) crashed_thread.threadNumber, codeType];
        
        int regColumn = 1;
        for (PLCrashReportRegisterInfo *reg in crashed_thread.registers) {
            NSString *reg_fmt;
            
            /* Use 32-bit or 64-bit fixed width format for the register values */
            if (lp64)
                reg_fmt = @"%6s:\t0x%016" PRIx64 " ";
            else
                reg_fmt = @"%6s:\t0x%08" PRIx64 " ";
            
            [xmlString appendFormat: reg_fmt, [reg.registerName UTF8String], reg.registerValue];
            
            if (regColumn % 4 == 0)
                [xmlString appendString: @"\n"];
            regColumn++;
        }
        
        if (regColumn % 3 != 0)
            [xmlString appendString: @"\n"];
        
        [xmlString appendString: @"\n"];
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
		
        NSString *device = @"\?\?\? (\?\?\?)";
        
#ifdef _ARM_ARCH_7 
        device = @"armv7";
#else
        device = @"armv6";
#endif
        
		/* base_address - terminating_address file_name identifier (<version>) <uuid> file_path */
		[xmlString appendFormat:@"0x%" PRIx64 " - 0x%" PRIx64 "  %@ %@ <%@> %@\n",
		 imageInfo.imageBaseAddress,
		 imageInfo.imageBaseAddress + imageInfo.imageSize,
		 [imageInfo.imageName lastPathComponent],
		 device,
		 uuid,
		 imageInfo.imageName];
	}
	
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
	NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
	[request setValue:contentType forHTTPHeaderField:@"Content-type"];
	
	NSMutableData *postBody =  [NSMutableData data];
	[postBody appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
	[postBody appendData:[@"Content-Disposition: form-data; name=\"xmlstring\"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
	[postBody appendData:[xml dataUsingEncoding:NSUTF8StringEncoding]];
	[postBody appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
	[request setHTTPBody:postBody];
	
	_serverResult = CrashReportStatusUnknown;
	_statusCode = 200;
	
	//Release when done in the delegate method
	_responseData = [[NSMutableData alloc] init];
	
	if (_delegate != nil && [_delegate respondsToSelector:@selector(connectionOpened)])
	{
		[_delegate connectionOpened];
	}
	
	_urlConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
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
	
    // check if the next call ran successfully the last time
	if (_crashReportAnalyzerStarted == 0)
	{
		// mark the start of the routine
		_crashReportAnalyzerStarted = 1;
		[[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithInt:_crashReportAnalyzerStarted] forKey:kCrashReportAnalyzerStarted];
		
        
        // Try loading the crash report
        _crashData = [[NSData alloc] initWithData:[crashReporter loadPendingCrashReportDataAndReturnError: &error]];
	
        NSString *cacheFilename = [NSString stringWithFormat: @"%.0f", [NSDate timeIntervalSinceReferenceDate]];
	
        if (_crashData == nil) {
            NSLog(@"Could not load crash report: %@", error);
            goto finish;
        } else {
            [_crashData writeToFile:[_crashesDir stringByAppendingPathComponent: cacheFilename] atomically:YES];
        }
	
		// We could send the report from here, but we'll just print out
		// some debugging info instead
		PLCrashReport *report = [[[PLCrashReport alloc] initWithData: _crashData error: &error] autorelease];
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
