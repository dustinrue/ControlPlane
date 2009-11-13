	/*
	 * Author: Andreas Linde <mail@andreaslinde.de>
	 *
	 * Copyright (c) 2009 Andreas Linde. All rights reserved.
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
	 
These are the main features of this demo project:
- (Automatically) send crash reports to a developers database
- Let the user decide per crash to (not) send data or always send
- The user has the option to provide additional information in the settings, like email address for contacting the user
- Give the user immediate feedback if the crash is known and will be fixed in the next update, or if the update is already waiting at Apple for approval, or if the update is already available to install

These are the main features on backend side for the developer:
- Admin interface to manage the incoming crash log data
- Script to symbolicate crash logs on the database, needs to be run on a mac with access to the DSYM files
- Automatic grouping of crash files for most likely same kind of crashes
- Maintain crash reports and sort them by using simple patterns. Automatically know how many times a bug has occured and easily filter the new ones in the DB
- Assign bugfix versions for each crash group and define a status for each version, which can be used to provide some feedback for the user
  like: Bug already fixed, new version with bugfix already available, etc.

Server side files:
- /server/database_schema.sql contains all the default tables
- /server/crash_v200.php is the file that is invoked by the iPhone app
- /server/config.php contains database access information
- /server/admin/ contains all administration scripts
- /server/admin/symbolicate.php needs to be copied to a local mac, and the url has to be adjusted to access the scripts on your server

Server Installation:
- Copy the server scripts to your web server
- Execute the SQL statements from database_schema.sql in your MySQL database on the web server

Server Database Configuration:
- Adjust settings in /server/CONFIG.PHP:
    $server = 'your.server.com';            // database server hostname
    $loginsql = 'database_username';        // username to access the database
    $passsql = 'database_password';         // password for the above username
    $base = 'database_name';                // database name which contains the below listed tables
- Adjust $default_amount_crashes, this defines the amount of crashes listed right away per pattern, if there are more, those are shown after clicking on a link at the end of the shortened list
- Adjust your local timezone in the last line: date_default_timezone_set('Europe/Berlin') (see http://de3.php.net/manual/en/timezones.php)
- If you DO NOT want to limit the server to accept only dataa for your applications:
  - set $acceptallapps to true
- Otherwise:
  - start the web interface
  - add the bundle identifiers of the permitted apps, e.g. "de.buzzworks.crashreporterdemo" (this is the same bundle identifier string as used in the info.plist of your app!)
  
Server Enable Push Notifications:
- NOTICE: Push Notification requires the Server PHP installation to have curl addon installed!
- NOTICE: Push Notifications are implemented using Prowl iPhone app and web service, you need the app and an Prowl API key!
- Adjust settings in /server/CONFIG.PHP:
    - set $push_activated to true
    - if you don't want a push message for every new pattern, set $push_newtype to false
    - adjust $push_amount_group to the amount of crash occurences of a pattern when a push message should be sent
    - add up to 5 comma separated prowl api keys into $push_prowlids to receive the push messages on the device
    - adjust $push_default_version, defines if you want to receive pushes for automatically created new versions for your apps
- If push is activated, check the web interface for push settings per app version
    
iPhone Project Installation:
- Include CrashReportSender.h and CrashReportSender.m into your project
- Include CrashReporter.framework into your project
- In your appDelegate.m include
  #import "CrashReportSender.h"
- In your appDelegate applicationDidFinishLaunching function include
  if ([[CrashReportSender sharedCrashReportSender] hasPendingCrashReport]) {
		[[CrashReportSender sharedCrashReportSender] scheduleCrashReportSubmissionToURL:CRASH_REPORTER_URL];
	}  
  where CRASH_REPORTER_URL points to your crash_v200.php URL
- Done.
- When testing the connection and a server side error appears after sending a crash log, the error code is printed in the console. Error code values are listed in CrashReportSender.h

Feel free to add enhancements, fixes, changes and provide them back to the community!

Thanks
Andreas Linde
http://www.andreaslinde.com/
http://www.buzzworks.de/