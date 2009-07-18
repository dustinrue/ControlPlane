<?php


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

define("VERSION_STATUS_UNKNOWN", 0);    // bug may get fixed in an unknown version
define("VERSION_STATUS_ASSIGNED", 1);   // bug will get fixed in a defined version
define("VERSION_STATUS_SUBMITTED", 2);	// bug is fixed in a defined version, and the version has been submitted to the publisher
define("VERSION_STATUS_AVAILABLE", 3);	// bug is fixed in a defined version, and the version is available for the customer

define("RESULT_FAILURE", -1);           // resultcode if sending crash log ended in failure

$statusversions = array(0 => 'Unknown', 1 => 'In development', 2 => 'Submitted', 3 => 'Available');

$server = 'your.server.com';            // database server hostname
$loginsql = 'database_username';        // username to access the database
$passsql = 'database_password';         // password for the above username
$base = 'database_name';                // database name which contains the below listed tables

$dbcrashtable = 'crash';                // contains the actual crash log data
$dbgrouptable = 'crash_groups';         // contains the automatically generated grouping definitions for crash log data
$dbapptable = 'apps';                   // contains a list of allowed applications which crash logs will be accepted
$dbversiontable = 'versions';           // contains a list of versions per application with a status, that can be used to provide the user with some feedback
$dbsymbolicatetable = 'symbolicated';   // contains a todo list of crash log data which has to be symbolicated by an external task (symbolicate.php)

$acceptallapps = false;                  // if set to true, all crash logs will be added and todo entries for symbolication will be added too
                                        // otherwise the app identifiers need to be added in the UI and todo can be turned on individually

?>