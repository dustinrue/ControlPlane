<?php


	/*
	 * Author: Andreas Linde <mail@andreaslinde.de>
	 *
	 * Copyright (c) 2009-2011 Andreas Linde.
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

define("VERSION_STATUS_UNKNOWN", 0);        // bug may get fixed in an unknown version
define("VERSION_STATUS_ASSIGNED", 1);       // bug will get fixed in a defined version
define("VERSION_STATUS_SUBMITTED", 2);      // bug is fixed in a defined version, and the version has been submitted to the publisher
define("VERSION_STATUS_AVAILABLE", 3);      // bug is fixed in a defined version, and the version is available for the customer
define("VERSION_STATUS_DISCONTINUED", 4);   // version is no longer maintained, don't accept crash logs

// notify status per version
define("NOTIFY_OFF", 0);                      // don't send notifications
define("NOTIFY_ACTIVATED", 1);                // send notifications for first and for $notify_amount_group
define("NOTIFY_ACTIVATED_AMOUNT", 2);         // send notifications for $notify_amount_group only

// sending crash log ended in failure error codes
define("FAILURE_DATABASE_NOT_AVAILABLE", -1);           // database cannot be accessed, check hostname, username, password and database name settings in config.php 
define("FAILURE_INVALID_INCOMING_DATA", -2);           	// incoming data may not be added, because e.g. bundle identifier wasn't found 
define("FAILURE_INVALID_POST_DATA", -3);           		// the post request didn't contain valid data 
define("FAILURE_SQL_SEARCH_APP_NAME", -10);    			// SQL for finding the bundle identifier in the database failed
define("FAILURE_SQL_FIND_KNOWN_PATTERNS", -11); 		// SQL for getting all the known bug patterns for the current app version in the database failed
define("FAILURE_SQL_UPDATE_PATTERN_OCCURANCES", -12); 	// SQL for updating the occurances of this pattern in the database failed
define("FAILURE_SQL_CHECK_BUGFIX_STATUS", -13); 		// SQL for checking the status of the bugfix version in the database failed
define("FAILURE_SQL_ADD_PATTERN", -14); 				// SQL for creating a new pattern for this bug and set amount of occurrances to 1 in the database failed
define("FAILURE_SQL_CHECK_VERSION_EXISTS", -15); 		// SQL for checking if the version is already added in the database failed
define("FAILURE_SQL_ADD_VERSION", -16); 				// SQL for adding a new version in the database failed
define("FAILURE_SQL_ADD_CRASHLOG", -17);                // SQL for adding crash log in the database failed
define("FAILURE_SQL_ADD_SYMBOLICATE_TODO", -18);        // SQL for adding a symoblicate todo entry in the database failed
define("FAILURE_XML_VERSION_NOT_ALLOWED", -20); 		// XML: Version string contains not allowed characters, only alphanumberical including space and . are allowed
define("FAILURE_XML_SENDER_VERSION_NOT_ALLOWED", -21);  // XML: Sender ersion string contains not allowed characters, only alphanumberical including space and . are allowed
define("FAILURE_VERSION_DISCONTINUED", -30);            // The app version causing this crash has been discontinued
define("FAILURE_PHP_XMLREADER_CLASS", -40);             // PHP: XMLReader class is not available in PHP
define("FAILURE_PHP_PROWL_CLASS", -41);                 // PHP: Prowl class is not available in PHP
define("FAILURE_PHP_CURL_LIB", -41);                    // PHP: cURL library missing vital functions or does not support SSL. cURL w/SSL is required to execute ProwlPHP.

define("SEARCH_TYPE_ID", 0);                            // Search for a crash ID
define("SEARCH_TYPE_DESCRIPTION", 1);                   // Search for in the crash descriptions
define("SEARCH_TYPE_CRASHLOG", 2);                      // Search for in the crashlogs

$statusversions = array(0 => 'Unknown', 1 => 'In development', 2 => 'Submitted', 3 => 'Available', 4 => 'Discontinued');

$server = 'your.server.com';                    // database server hostname
$loginsql = 'database_username';                // username to access the database
$passsql = 'database_password';                 // password for the above username
$base = 'database_name';                        // database name which contains the below listed tables

$dbcrashtable = 'crash';                        // contains the actual crash log data
$dbgrouptable = 'crash_groups';                 // contains the automatically generated grouping definitions for crash log data
$dbapptable = 'apps';                           // contains a list of allowed applications which crash logs will be accepted
$dbversiontable = 'versions';                   // contains a list of versions per application with a status, that can be used to provide the user with some feedback
$dbsymbolicatetable = 'symbolicated';           // contains a todo list of crash log data which has to be symbolicated by an external task (symbolicate.php)

$acceptallapps = false;                         // if set to true, all crash logs will be added and todo entries for symbolication will be added too
                                                // otherwise the app identifiers need to be added in the UI and todo can be turned on individually

$push_activated = false;                        // activate push notifications via Prowl?
$push_prowlids = '';                            // Up to 5 comma separated prowl api keys which should get the notifications
                                                // can also be set per app, this is a global setting also effective when acceptallapps is true

$boxcar_activated = true;						// Separate setting for Boxcar, so as to not interfere with Prowl config
$boxcar_uid = "";								// Boxcar user email
$boxcar_pwd = "";								// Boxcar password

$mail_activated = true;					        // activate email notifications
$mail_addresses = '';                           // , separated mail addresses to send notification emails to
                                                // can also be set per app, this is a global setting also effective when acceptallapps is true

$mail_from = 'sender@yourdomain.com';           // sender address used for notification emails
$crash_url = 'http://www.yourserver.com/';      // if the mail should contain a link to the crash, at the base url like http://www.yourserver.com/
                                                // "admin/crashes.php?..." with a direct link to the crash group will be added automatically!

$notify_amount_group = 10;                      // the amount of crashes found for a type which invokes a push notification to be send, 1 to deactivate
$notify_default_version = NOTIFY_OFF;           // default behaviour for a new app version push behaviour

$default_amount_crashes = 5;				    // amount of crashes shown by default per pattern, enhances page loading speed in case there are a lot of crashes

$color24h = "red";                              // color of timestamp if the latest crash is within the last 24h in Version view
$color48h = "orange";                           // color of timestamp if the latest crash is within the last 48h in Version view
$color72h = "black";                            // color of timestamp if the latest crash is within the last 72h in Version view
$colorOther = "grey";                           // color of timestamp for older last crashes in Version view

$admintitle = "CrashReporter Admin Interface";  // Adjust this string to your own title string shown on top of every page

$createIssueTitle = "New crash type";           // The title given for a new issue

$hockeyAppURL = 'http://0.0.0.0:3000/';         // The HockeyApp server address to route the crashes to, this should normally never be edited!

date_default_timezone_set('Europe/Berlin');	    // set the default timezone (see http://de3.php.net/manual/en/timezones.php)

?>