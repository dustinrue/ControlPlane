/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Kent Sutherland
 *
 * Copyright (c) 2011 Andreas Linde & Kent Sutherland.
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

#import "BWQuincyManager.h"
#import <sys/sysctl.h>

@interface BWQuincyManager(private)
- (void) startManager;

- (void) _postXML:(NSString*)xml toURL:(NSURL*)url;
- (void) searchCrashLogFile:(NSString *)path;
- (BOOL) hasPendingCrashReport;
- (void) returnToMainApplication;
@end

@interface BWQuincyUI(private)
- (void) askCrashReportDetails;
- (void) endCrashReporter;
@end

const CGFloat kCommentsHeight = 105;
const CGFloat kDetailsHeight = 285;

@implementation BWQuincyManager

@synthesize delegate = _delegate;
@synthesize submissionURL = _submissionURL;
@synthesize companyName = _companyName;
@synthesize appIdentifier = _appIdentifier;
@synthesize autoSubmitCrashReport = _autoSubmitCrashReport;

+ (BWQuincyManager *)sharedQuincyManager {
	static BWQuincyManager *quincyManager = nil;
	
	if (quincyManager == nil) {
		quincyManager = [[BWQuincyManager alloc] init];
	}
	
	return quincyManager;
}

- (id) init {
  if ((self = [super init])) {
		_serverResult = CrashReportStatusFailureDatabaseNotAvailable;
		_quincyUI = nil;
    
		_submissionURL = nil;
    _appIdentifier = nil;
    
    _crashFile = nil;
    
		self.delegate = nil;
		self.companyName = @"";		
	}
	return self;
}

- (void)dealloc {
	_companyName = nil;
	_delegate = nil;
	_submissionURL = nil;
  _appIdentifier = nil;
  
  [_crashFile release];
	[_quincyUI release];
	
	[super dealloc];
}

- (void) searchCrashLogFile:(NSString *)path {
	NSFileManager* fman = [NSFileManager defaultManager];
	
  NSError* error;
	NSMutableArray* filesWithModificationDate = [NSMutableArray array];
	NSArray* crashLogFiles = [fman contentsOfDirectoryAtPath:path error:&error];
	NSEnumerator* filesEnumerator = [crashLogFiles objectEnumerator];
	NSString* crashFile;
	while((crashFile = [filesEnumerator nextObject])) {
		NSString* crashLogPath = [path stringByAppendingPathComponent:crashFile];
		NSDate* modDate = [[[NSFileManager defaultManager] attributesOfItemAtPath:crashLogPath error:&error] fileModificationDate];
		[filesWithModificationDate addObject:[NSDictionary dictionaryWithObjectsAndKeys:crashFile,@"name",crashLogPath,@"path",modDate,@"modDate",nil]];
	}
	
	NSSortDescriptor* dateSortDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"modDate" ascending:YES] autorelease];
	NSArray* sortedFiles = [filesWithModificationDate sortedArrayUsingDescriptors:[NSArray arrayWithObject:dateSortDescriptor]];
	
	NSPredicate* filterPredicate = [NSPredicate predicateWithFormat:@"name BEGINSWITH %@", [self applicationName]];
	NSArray* filteredFiles = [sortedFiles filteredArrayUsingPredicate:filterPredicate];
	
	_crashFile = [[[filteredFiles valueForKeyPath:@"path"] lastObject] copy];
}

#pragma mark -
#pragma mark setter
- (void)setSubmissionURL:(NSString *)anSubmissionURL {
  if (_submissionURL != anSubmissionURL) {
    [_submissionURL release];
    _submissionURL = [anSubmissionURL copy];
  }
  
  [self performSelector:@selector(startManager) withObject:nil afterDelay:0.1f];
}

- (void)setAppIdentifier:(NSString *)anAppIdentifier {    
  if (_appIdentifier != anAppIdentifier) {
    [_appIdentifier release];
    _appIdentifier = [anAppIdentifier copy];
  }
  
  [self setSubmissionURL:@"https://rink.hockeyapp.net/"];
}

- (void)storeLastCrashDate:(NSDate *) date {
  [[NSUserDefaults standardUserDefaults] setValue:date forKey:@"CrashReportSender.lastCrashDate"];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSDate *)loadLastCrashDate {
  NSDate *date = [[NSUserDefaults standardUserDefaults] valueForKey:@"CrashReportSender.lastCrashDate"];
  return date ?: [NSDate distantPast];
}

- (void)storeAppVersion:(NSString *) version {
  [[NSUserDefaults standardUserDefaults] setValue:version forKey:@"CrashReportSender.appVersion"];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)loadAppVersion {
  NSString *appVersion = [[NSUserDefaults standardUserDefaults] valueForKey:@"CrashReportSender.appVersion"];
  return appVersion ?: nil;
}

#pragma mark -
#pragma mark GetCrashData

- (BOOL) hasPendingCrashReport {
	BOOL returnValue = NO;
  
  NSString *appVersion = [self loadAppVersion];
  NSDate *lastCrashDate = [self loadLastCrashDate];

  if (!appVersion || ![appVersion isEqualToString:[self applicationVersion]] || [lastCrashDate isEqualToDate:[NSDate distantPast]]) {
    [self storeAppVersion:[self applicationVersion]];
    [self storeLastCrashDate:[NSDate date]];
    return NO;
  }
  
  NSArray* libraryDirectories = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, TRUE);
  // Snow Leopard is having the log files in another location
  [self searchCrashLogFile:[[libraryDirectories lastObject] stringByAppendingPathComponent:@"Logs/DiagnosticReports"]];
  if (_crashFile == nil) {
    [self searchCrashLogFile:[[libraryDirectories lastObject] stringByAppendingPathComponent:@"Logs/CrashReporter"]];
    if (_crashFile == nil) {
      NSString *sandboxFolder = [NSString stringWithFormat:@"/Containers/%@/Data/Library", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"]];
      if ([[libraryDirectories lastObject] rangeOfString:sandboxFolder].location != NSNotFound) {
        NSString *libFolderName = [[libraryDirectories lastObject] stringByReplacingOccurrencesOfString:sandboxFolder withString:@""];
        [self searchCrashLogFile:[libFolderName stringByAppendingPathComponent:@"Logs/DiagnosticReports"]];
      }
    }
  }
  
  if (_crashFile) {
    NSError* error;
    
    NSDate *crashLogModificationDate = [[[NSFileManager defaultManager] attributesOfItemAtPath:_crashFile error:&error] fileModificationDate];
    unsigned long long crashLogFileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:_crashFile error:&error] fileSize];
    if ([crashLogModificationDate compare: lastCrashDate] == NSOrderedDescending && crashLogFileSize > 0) {
      [self storeLastCrashDate:crashLogModificationDate];
      returnValue = YES;
    }
  }
	
	return returnValue;
}

- (void) returnToMainApplication {
	if ( self.delegate != nil && [self.delegate respondsToSelector:@selector(showMainApplicationWindow)])
		[self.delegate showMainApplicationWindow];
}

- (void) startManager {
  if ([self hasPendingCrashReport]) {
    if (!self.autoSubmitCrashReport) {
      _quincyUI = [[BWQuincyUI alloc] init:self crashFile:_crashFile companyName:_companyName applicationName:[self applicationName]];
      [_quincyUI askCrashReportDetails];
    } else {
      NSError* error = nil;
      NSString *crashLogs = [NSString stringWithContentsOfFile:_crashFile encoding:NSUTF8StringEncoding error:&error];
      if (!error) {
        NSString *lastCrash = [[crashLogs componentsSeparatedByString: @"**********\n\n"] lastObject];
        
        NSString* description = @"";
        
        if (_delegate && [_delegate respondsToSelector:@selector(crashReportDescription)]) {
          description = [_delegate crashReportDescription];
        }
              
        [self sendReportCrash:lastCrash description:description];
      }
    }
  } else {
    [self returnToMainApplication];
  }
}

- (NSString*) modelVersion {
  NSString * modelString  = nil;
  int        modelInfo[2] = { CTL_HW, HW_MODEL };
  size_t     modelSize;
	
  if (sysctl(modelInfo,
             2,
             NULL,
             &modelSize,
             NULL, 0) == 0) {
    void * modelData = malloc(modelSize);
    
    if (modelData) {
      if (sysctl(modelInfo,
                 2,
                 modelData,
                 &modelSize,
                 NULL, 0) == 0) {
        modelString = [NSString stringWithUTF8String:modelData];
      }
      
      free(modelData);
    }
  }
  
  return modelString;
}



- (void) cancelReport {
  [self returnToMainApplication];
}


- (void) sendReportCrash:(NSString*)crashContent
             description:(NSString*)notes
{
  NSString *userid = @"";
	NSString *contact = @"";
		
	SInt32 versionMajor, versionMinor, versionBugFix;
	if (Gestalt(gestaltSystemVersionMajor, &versionMajor) != noErr) versionMajor = 0;
	if (Gestalt(gestaltSystemVersionMinor, &versionMinor) != noErr)  versionMinor= 0;
	if (Gestalt(gestaltSystemVersionBugFix, &versionBugFix) != noErr) versionBugFix = 0;
	
	NSString* xml = [NSString stringWithFormat:@"<crash><applicationname>%s</applicationname><bundleidentifier>%s</bundleidentifier><systemversion>%@</systemversion><senderversion>%@</senderversion><version>%@</version><platform>%@</platform><userid>%@</userid><contact>%@</contact><description><![CDATA[%@]]></description><log><![CDATA[%@]]></log></crash>",
             [[self applicationName] UTF8String],
             [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"] UTF8String],
             [NSString stringWithFormat:@"%i.%i.%i", versionMajor, versionMinor, versionBugFix],
             [self applicationVersion],
             [self applicationVersion],
             [self modelVersion],
             userid,
             contact,
             notes,
             crashContent
             ];

    
    [self returnToMainApplication];
	
    [self _postXML:[NSString stringWithFormat:@"<crashes>%@</crashes>", xml] toURL:[NSURL URLWithString:self.submissionURL]];
}

- (void)_postXML:(NSString*)xml toURL:(NSURL*)url {
	NSMutableURLRequest *request = nil;
  NSString *boundary = @"----FOO";
  
  if (self.appIdentifier) {
    request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@api/2/apps/%@/crashes",
                                                                        self.submissionURL,
                                                                        [self.appIdentifier stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
                                                                        ]
                                                   ]];
  } else {
    request = [NSMutableURLRequest requestWithURL:url];
  }
	
	[request setValue:@"Quincy/Mac" forHTTPHeaderField:@"User-Agent"];
  [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
	[request setTimeoutInterval: 15];
	[request setHTTPMethod:@"POST"];
	NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
	[request setValue:contentType forHTTPHeaderField:@"Content-type"];
	
	NSMutableData *postBody =  [NSMutableData data];	
  [postBody appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
  if (self.appIdentifier) {
    [postBody appendData:[@"Content-Disposition: form-data; name=\"xml\"; filename=\"crash.xml\"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [postBody appendData:[[NSString stringWithFormat:@"Content-Type: text/xml\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
  } else {
    [postBody appendData:[@"Content-Disposition: form-data; name=\"xmlstring\"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
	}
	[postBody appendData:[xml dataUsingEncoding:NSUTF8StringEncoding]];
  [postBody appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
	[request setHTTPBody:postBody];
  
	_serverResult = CrashReportStatusUnknown;
	_statusCode = 200;
	
	NSHTTPURLResponse *response = nil;
	NSError *error = nil;
	
	NSData *responseData = nil;
	responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
	_statusCode = [response statusCode];
  
	if (responseData != nil) {
		if (_statusCode >= 200 && _statusCode < 400) {
			NSXMLParser *parser = [[NSXMLParser alloc] initWithData:responseData];
			// Set self as the delegate of the parser so that it will receive the parser delegate methods callbacks.
			[parser setDelegate:self];
			// Depending on the XML document you're parsing, you may want to enable these features of NSXMLParser.
			[parser setShouldProcessNamespaces:NO];
			[parser setShouldReportNamespacePrefixes:NO];
			[parser setShouldResolveExternalEntities:NO];
			
			[parser parse];
			
			[parser release];
		}
	}
}


#pragma mark NSXMLParser

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
	if (qName) {
		elementName = qName;
	}
	
	if ([elementName isEqualToString:@"result"]) {
		_contentOfProperty = [NSMutableString string];
	}
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
	if (qName) {
		elementName = qName;
	}
	
	if ([elementName isEqualToString:@"result"]) {
		if ([_contentOfProperty intValue] > _serverResult) {
			_serverResult = [_contentOfProperty intValue];
		}
	}
}


- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
	if (_contentOfProperty) {
		// If the current element is one whose content we care about, append 'string'
		// to the property that holds the content of the current element.
		if (string != nil) {
			[_contentOfProperty appendString:string];
		}
	}
}


#pragma mark GetterSetter

- (NSString *) applicationName {
	NSString *applicationName = [[[NSBundle mainBundle] localizedInfoDictionary] valueForKey: @"CFBundleExecutable"];
	
	if (!applicationName)
		applicationName = [[[NSBundle mainBundle] infoDictionary] valueForKey: @"CFBundleExecutable"];
	
	return applicationName;
}


- (NSString*) applicationVersionString {
	NSString* string = [[[NSBundle mainBundle] localizedInfoDictionary] valueForKey: @"CFBundleShortVersionString"];
	
	if (!string)
		string = [[[NSBundle mainBundle] infoDictionary] valueForKey: @"CFBundleShortVersionString"];
	
	return string;
}

- (NSString *) applicationVersion {
	NSString* string = [[[NSBundle mainBundle] localizedInfoDictionary] valueForKey: @"CFBundleVersion"];
	
	if (!string)
		string = [[[NSBundle mainBundle] infoDictionary] valueForKey: @"CFBundleVersion"];
	
	return string;
}

@end




@implementation BWQuincyUI

- (id)init:(id)delegate crashFile:(NSString *)crashFile companyName:(NSString *)companyName applicationName:(NSString *)applicationName {
	
	self = [super initWithWindowNibName: @"BWQuincyMain"];
	
	if ( self != nil) {
		_xml = nil;
		_delegate = delegate;
		_crashFile = crashFile;
		_companyName = companyName;
		_applicationName = applicationName;
		[self setShowComments: YES];
		[self setShowDetails: NO];
    
		NSRect windowFrame = [[self window] frame];
		windowFrame.size = NSMakeSize(windowFrame.size.width, windowFrame.size.height - kDetailsHeight);
		windowFrame.origin.y -= kDetailsHeight;
		[[self window] setFrame: windowFrame
                    display: YES
                    animate: NO];
    
	}
	return self;	
}


- (void) endCrashReporter {
	[self close];
}


- (IBAction) showComments: (id) sender {
	NSRect windowFrame = [[self window] frame];
	
	if ([sender intValue]) {
		[self setShowComments: NO];
		
		windowFrame.size = NSMakeSize(windowFrame.size.width, windowFrame.size.height + kCommentsHeight);
    windowFrame.origin.y -= kCommentsHeight;
		[[self window] setFrame: windowFrame
                    display: YES
                    animate: YES];
		
		[self setShowComments: YES];
	} else {
		[self setShowComments: NO];
		
		windowFrame.size = NSMakeSize(windowFrame.size.width, windowFrame.size.height - kCommentsHeight);
    windowFrame.origin.y += kCommentsHeight;
		[[self window] setFrame: windowFrame
                    display: YES
                    animate: YES];
	}
}


- (IBAction) showDetails:(id)sender {
	NSRect windowFrame = [[self window] frame];
  
	windowFrame.size = NSMakeSize(windowFrame.size.width, windowFrame.size.height + kDetailsHeight);
  windowFrame.origin.y -= kDetailsHeight;
	[[self window] setFrame: windowFrame
                  display: YES
                  animate: YES];
	
	[self setShowDetails:YES];
  
}


- (IBAction) hideDetails:(id)sender {
	NSRect windowFrame = [[self window] frame];
  
	[self setShowDetails:NO];
  
	windowFrame.size = NSMakeSize(windowFrame.size.width, windowFrame.size.height - kDetailsHeight);
  windowFrame.origin.y += kDetailsHeight;
	[[self window] setFrame: windowFrame
                  display: YES
                  animate: YES];
}


- (IBAction) cancelReport:(id)sender {
	[self endCrashReporter];
	[NSApp stopModal];
	
	if ( _delegate != nil && [_delegate respondsToSelector:@selector(cancelReport)])
		[_delegate cancelReport];
}

- (void) _sendReportAfterDelay {
  if ( _delegate != nil && [_delegate respondsToSelector:@selector(sendReport:)]) {
    NSString *notes = [NSString stringWithFormat:@"Comments:\n%@\n\nConsole:\n%@", [descriptionTextField stringValue], _consoleContent];
    
    [_delegate sendReportCrash:_crashLogContent description:notes];
  }
}

- (IBAction) submitReport:(id)sender {
	[submitButton setEnabled:NO];
	
	[[self window] makeFirstResponder: nil];
	
    [self performSelector:@selector(_sendReportAfterDelay) withObject:nil afterDelay:0.01];
    
	[self endCrashReporter];
	[NSApp stopModal];
}


- (void) askCrashReportDetails {
	NSError *error;
	
	[[self window] setTitle:[NSString stringWithFormat:NSLocalizedString(@"Problem Report for %@", @"Window title"), _applicationName]];
  
	[[descriptionTextField cell] setPlaceholderString:NSLocalizedString(@"Please describe any steps needed to trigger the problem", @"User description placeholder")];
	[noteText setStringValue:NSLocalizedString(@"No personal information will be sent with this report.", @"Note text")];
  
	// get the crash log
	NSString *crashLogs = [NSString stringWithContentsOfFile:_crashFile encoding:NSUTF8StringEncoding error:&error];
	NSString *lastCrash = [[crashLogs componentsSeparatedByString: @"**********\n\n"] lastObject];
	
	_crashLogContent = lastCrash;
	
	// get the console log
	NSEnumerator *theEnum = [[[NSString stringWithContentsOfFile:@"/private/var/log/system.log" encoding:NSUTF8StringEncoding error:&error] componentsSeparatedByString: @"\n"] objectEnumerator];
	NSString* currentObject;
	NSMutableArray* applicationStrings = [NSMutableArray array];
	
	NSString* searchString = [[_delegate applicationName] stringByAppendingString:@"["];
	while ( (currentObject = [theEnum nextObject]) ) {
		if ([currentObject rangeOfString:searchString].location != NSNotFound)
			[applicationStrings addObject: currentObject];
	}
	
	_consoleContent = [NSMutableString string];
	
  NSInteger i;
  for(i = ((NSInteger)[applicationStrings count])-1; (i>=0 && i>((NSInteger)[applicationStrings count])-100); i--) {
		[_consoleContent appendString:[applicationStrings objectAtIndex:i]];
		[_consoleContent appendString:@"\n"];
	}
	
  // Now limit the content to CRASHREPORTSENDER_MAX_CONSOLE_SIZE (default: 50kByte)
  if ([_consoleContent length] > CRASHREPORTSENDER_MAX_CONSOLE_SIZE) {
    _consoleContent = (NSMutableString *)[_consoleContent substringWithRange:NSMakeRange([_consoleContent length]-CRASHREPORTSENDER_MAX_CONSOLE_SIZE-1, CRASHREPORTSENDER_MAX_CONSOLE_SIZE)]; 
  }
  
	[crashLogTextView setString:[NSString stringWithFormat:@"%@\n\n%@", _crashLogContent, _consoleContent]];
  
  
	NSBeep();
	[NSApp runModalForWindow:[self window]];
}


- (void)dealloc {
	_companyName = nil;
	_delegate = nil;
	
	[super dealloc];
}


- (BOOL)showComments {
	return showComments;
}


- (void)setShowComments:(BOOL)value {
	showComments = value;
}


- (BOOL)showDetails {
	return showDetails;
}


- (void)setShowDetails:(BOOL)value {
	showDetails = value;
}

#pragma mark NSTextField Delegate

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
  BOOL commandHandled = NO;
  
  if (commandSelector == @selector(insertNewline:)) {
    [textView insertNewlineIgnoringFieldEditor:self];
    commandHandled = YES;
  }
  
  return commandHandled;
}

@end

