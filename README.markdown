    Author: Andreas Linde <mail@andreaslinde.de>

    Copyright (c) 2009-2011 Andreas Linde.
    All rights reserved.

    Permission is hereby granted, free of charge, to any person
    obtaining a copy of this software and associated documentation
    files (the "Software"), to deal in the Software without
    restriction, including without limitation the rights to use,
    copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following
    conditions:

    The above copyright notice and this permission notice shall be
    included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
    OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
    HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
    OTHER DEALINGS IN THE SOFTWARE.


# Main features of QuincyKit

- (Automatically) send crash reports to a developers database
- Let the user decide per crash to (not) send data or always send
- The user has the option to provide additional information in the settings, like email address for contacting the user
- Give the user immediate feedback if the crash is known and will be fixed in the next update, or if the update is already waiting at Apple for approval, or if the update is already available to install


# Main features on backend side for the developer

- Admin interface to manage the incoming crash log data
- Script to symbolicate crash logs on the database, needs to be run on a mac with access to the DSYM files
- Automatic grouping of crash files for most likely same kind of crashes
- Maintain crash reports and sort them by using simple patterns. Automatically know how many times a bug has occured and easily filter the new ones in the DB
- Assign bugfix versions for each crash group and define a status for each version, which can be used to provide some feedback for the user
  like: Bug already fixed, new version with bugfix already available, etc.


## Server side files

- `/server/database_schema.sql` contains all the default tables
- `/server/crash_v200.php` is the file that is invoked by the iPhone app
- `/server/config.php` contains database access information
- `/server/test_setup.php` simple script that checks if everything required on the server is available
- `/server/admin/` contains all administration scripts
- `/server/admin/symbolicate.php` needs to be copied to a local mac, and the url has to be adjusted to access the scripts on your server


# SERVER INSTALLATION

The server requires at least PHP 5.2 and a MySQL server installation!

- Copy the server scripts to your web server:
  All files inside /server except the content of the `/server/local` directory
- Execute the SQL statements from `database_schema.sql` in your MySQL database on the web server


## SERVER DATABASE CONFIGURATION

- Adjust settings in `/server/CONFIG.PHP`:

    $server = 'your.server.com';            // database server hostname
    $loginsql = 'database_username';        // username to access the database
    $passsql = 'database_password';         // password for the above username
    $base = 'database_name';                // database name which contains the below listed tables

- Adjust `$default_amount_crashes`, this defines the amount of crashes listed right away per pattern, if there are more, those are shown after clicking on a link at the end of the shortened list
- Adjust your local timezone in the last line: `date_default_timezone_set('Europe/Berlin')` (see [http://de3.php.net/manual/en/timezones.php](http://de3.php.net/manual/en/timezones.php "PHP: List of Supported Timezones - Manual"))
- If you DO NOT want to limit the server to accept only data for your applications:
  - set `$acceptallapps` to true
- Otherwise:
  - start the web interface
  - add the bundle identifiers of the permitted apps, e.g. `"de.buzzworks.crashreporterdemo"` (this is the same bundle identifier string as used in the `info.plist` of your app!)
- Invoke `test_setup.php` via the browser to check if everything is setup correctly and Push can be used or not

- If you are upgrading a previous edition, invoke 'migrate.php' first to update the database setup


## UPDATE TO QUINCYKIT 2.0

- Add the new database fields to the following tables:

  **apps**
  
        `hockeyappidentifier` text default NULL

  **crash**

        `jailbreak` int(11) unsigned default '0'
    
- If you are upgrading from an early version, please make sure the database follows the schema defined in *database_schema.sql*.


## SERVER ENABLE PUSH NOTIFICATIONS

- **NOTICE**: Push Notification requires the Server PHP installation to have curl addon installed!
- **NOTICE**: Push Notifications are implemented using Prowl iPhone app and web service, you need the app and an Prowl API key!
- Adjust settings in `/server/CONFIG.PHP`:
    - set `$push_activated` to true
    - if you don't want a push message for every new pattern, set `$push_newtype` to false
    - adjust `$notify_amount_group` to the amount of crash occurences of a pattern when a push message should be sent
    - add up to 5 comma separated prowl api keys into $push_prowlids to receive the push messages on the device
    - adjust `$notify_default_version`, defines if you want to receive pushes for automatically created new versions for your apps
- If push is activated, check the web interface for push settings per app version


# SETUP LOCAL SYMBOLIFICATION

- **NOTICE**: These are the instructions when using Mac OS X 10.6.2
- Copy the files inside of `/server/local` onto a local directory on your Intel Mac running at least Mac OS X 10.6.2 having the iPhone SDK 3.x installed
- Adjust settings in `local/serverconfig.php`
  - set `$hostname` to the server hostname running the server side part, e.g. `www.crashreporterdemo.com`
  - if the `/admin/` directory on the server is access restricted, set the required username into `$webuser` and password into `$webpwd`
  - adjust the path to access the scripts (will be appended to `$hostname`):
      - `$downloadtodosurl = '/admin/actionapi.php?action=getsymbolicationtodo';`	// the path to the script delivering the todo list
      - `$getcrashdataurl = '/admin/actionapi.php?action=getlogcrashid&id=';`		// the path to the script delivering the crashlog
      - `$updatecrashdataurl = '/admin/crash_update.php';`						// the path to the script updating the crashlog
- Make the modified symbolicatecrash.pl file from the `/server/local/` directory executable: `chmod + x symbolicatecrash.pl`
- Copy the `.app` package and `.app.dSYM` package of each version into any directory of your Mac
  Best is to add the version number to the directory of each version, so multiple versions of the same app can be symbolicated.
  Example:
  
        QuincyDemo_1_0/QuincyDemo.app
        QuincyDemo_1_0/QuincyDemo.app.dSYM
        QuincyDemoBeta_1_1/QuincyDemoBeta.app
        QuincyDemoBeta_1_1/QuincyDemoBeta.app.dSYM
      
- Test symbolification:
  - Download a crash report into the local directory from above
  - run `symbolicatecrash nameofthecrashlogfile .`
  - if the output shows function names and line numbers for your code and apples code, everything is fine and ready to go, otherwise there is a problem :(
- If test was successful, try to execute `php symbolicate.php`
  This will print some error message which can be ignored
- Open the web interface and check the crashlogs if they are now symbolicated
- If everything went fine, setup a cron job
- IMPORTANT: Don't forget to add new builds with `.app` and `.app.dSYM` packages to the directory, so symbolification will be done correctly
  There is currently no checking if a package is found in the directory before symbolification is started, no matter if it was or not, the result will be uploaded to the server
  

# IPHONE PROJECT INSTALLATION

- Include `BWQuincyManager.h`, `BWQuincyManager.m` and `Quincy.bundle` into your project
- Include `CrashReporter.framework` into your project
- Add the "-all_load" flag to your projects build configurations "Other Linker Flags"
- Add the Apple framework `SystemConfiguration.framework` to your project
- In your `appDelegate.h` include

        #import "BWQuincyManager.h"

  and let your appDelegate implement the protocol `BWQuincyManagerDelegate`
- In your appDelegate applicationDidFinishLaunching function include

        [[BWQuincyManager sharedQuincyManager] setSubmissionURL:@"http://yourserver.com/crash_v200.php"];
      
- Done.
- When testing the connection and a server side error appears after sending a crash log, the error code is printed in the console. Error code values are listed in `BWQuincyManager.h`


# MAC PROJECT INSTALLATION

- Include `Quincy.framework` into your project
- In your `appDelegate.h` include

        #import <Quincy/BWQuincyManager.h>

- In your appDelegate.h add the BWQuincyManagerDelegate protocol to your appDelegate

        @interface DemoAppDelegate : NSObject <BWQuincyManagerDelegate> {}

- In your `appDelegate` change the invocation of the main window to the following structure

        // this delegate method is required
        - (void) showMainApplicationWindow
        {
            // launch the main app window
            // remember not to automatically show the main window if using NIBs
            [window makeFirstResponder: nil];
            [window makeKeyAndOrderFront:nil];
        }


        - (void)applicationDidFinishLaunching:(NSNotification *)note
        {
          // Launch the crash reporter task
          [[BWQuincyManager sharedQuincyManager] setSubmissionURL:@"http://yourserver.com/crash_v200.php"];
          [[BWQuincyManager sharedQuincyManager] setDelegate:self];
        }

- Done.


# BRANCHES:
The branching structure follows the git flow concept, defined by Vincent Driessen: http://nvie.com/posts/a-successful-git-branching-model/

* Master branch:

	The main branch where the source code of HEAD always reflects a production-ready state.

* Develop branch:

	Consider this to be the main branch where the source code of HEAD always reflects a state with the latest delivered development changes for the next release. Some would call this the “integration branch”.

* Feature branches:

	These are used to develop new features for the upcoming or a distant future release. The essence of a feature branch is that it exists as long as the feature is in development, but will eventually be merged back into develop (to definitely add the new feature to the upcoming release) or discarded (in case of a disappointing experiment).

* Release branches:

	These branches support preparation of a new production release. By using this, the develop branch is cleared to receive features for the next big release.

* Hotfix branches:

	Hotfix branches are very much like release branches in that they are also meant to prepare for a new production release, albeit unplanned.


# ACKNOWLEDGMENTS

**The following 3rd party open source libraries have been used:**

- PLCrashReporter by Landon Fuller (http://code.google.com/p/plcrashreporter/)
- bluescreen css framework (http://blueprintcss.org/)


Feel free to add enhancements, fixes, changes and provide them back to the community!

Thanks  
Andreas Linde  
http://www.andreaslinde.com/
http://www.buzzworks.de/
http://www.hockeyapp.net/
