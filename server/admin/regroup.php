<?php

	/*
	 * Author: Andreas Linde <mail@andreaslinde.de>
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

//
// Download a crash
//
// This script downloads a given crash to a local file
//

require_once('../config.php');

function end_with_result($result)
{
	return '<html><body>'.$result.'</body></html>'; 
}

$allowed_args = ',bundleidentifier,version,';

$link = mysql_connect($server, $loginsql, $passsql)
    or die(end_with_result('No database connection'));
mysql_select_db($base) or die(end_with_result('No database connection'));

foreach(array_keys($_GET) as $k) {
    $temp = ",$k,";
    if(strpos($allowed_args,$temp) !== false) { $$k = $_GET[$k]; }
}

if (!isset($bundleidentifier)) $bundleidentifier = "";
if (!isset($version)) $version = "";
$applicationname = "";

if ($bundleidentifier == "" || $version == "") die(end_with_result('Wrong parameters'));

$query1 = "SELECT id, applicationname FROM ".$dbcrashtable." WHERE groupid = 0 and version = '".$version."' and bundleidentifier = '".$bundleidentifier."'";
$result1 = mysql_query($query1) or die(end_with_result('Error in SQL '.$query1));

$numrows1 = mysql_num_rows($result1);
if ($numrows1 > 0) {
    // get the status
    while ($row1 = mysql_fetch_row($result1)) {
        $crashid = $row1[0];
        $applicationname = $row1[1];
	    
	    // get the log data
        $logdata = "";

   	    $query = "SELECT log FROM ".$dbcrashtable." WHERE id = '".$crashid."' ORDER BY systemversion desc, timestamp desc LIMIT 1";
        $result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));

        $numrows = mysql_num_rows($result);
        if ($numrows > 0) {
            // get the status
            $row = mysql_fetch_row($result);
            $logdata = $row[0];
	
            mysql_free_result($result);
        }

        // first try to find the offset of the crashing thread to assign this crash to a crash group
	
        // this stores the offset which we need for grouping
        $crash_offset = "";
	
        // extract the block which contains the data of the crashing thread
        preg_match('%Thread [0-9]+ Crashed:\n(.*?)\n\n%s', $logdata, $matches);

        //make sure $matches[1] exists
        if (is_array($matches) && count($matches) >= 2)
        {
            $result = explode("\n", $matches[1]);
            foreach ($result as $line)
            {
                // search for the first occurance of the application name
                if (strpos($line, $applicationname) !== false)
                {
                    preg_match('/[0-9]+\s+[^\s]+\s+([^\s]+) /', $line, $matches);
    
                    if (count($matches) >= 2) {
                        $crash_offset = $matches[1];
                    }
                    break;
                }
            }
        }

        // stores the group this crashlog is associated to, by default to none
        $log_groupid = 0;
    
        // check if the version is already added and the status of the version and notify status
        $query = "SELECT id, status, notify FROM ".$dbversiontable." WHERE bundleidentifier = '".$bundleidentifier."' and version = '".$version."'";
        $result = mysql_query($query) or die(xml_for_result(FAILURE_SQL_CHECK_VERSION_EXISTS));
    
        $numrows = mysql_num_rows($result);
        if ($numrows == 0) {
            // version is not available, so add it with status VERSION_STATUS_AVAILABLE
            $query = "INSERT INTO ".$dbversiontable." (bundleidentifier, version, status, notify) values ('".$bundleidentifier."', '".$version."', ".VERSION_STATUS_UNKNOWN.", ".$notify_default_version.")";
            $result = mysql_query($query) or die(xml_for_result(FAILURE_SQL_ADD_VERSION));
        } else {
            $row = mysql_fetch_row($result);
            $version_status = $row[1];
            $notify = $row[2];
            mysql_free_result($result);
        }
        
        // if the offset string is not empty, we try a grouping
        if (strlen($crash_offset) > 0)
        {
            // get all the known bug patterns for the current app version
            $query = "SELECT id, fix, amount FROM ".$dbgrouptable." WHERE affected = '".$version."' and pattern = '".mysql_real_escape_string($crash_offset)."'";
            $result = mysql_query($query) or die(xml_for_result(FAILURE_SQL_FIND_KNOWN_PATTERNS));
    
            $numrows = mysql_num_rows($result);
            
            if ($numrows == 1)
            {
                // assign this bug to the group
                $row = mysql_fetch_row($result);
                $log_groupid = $row[0];
                $amount = $row[2];
    
                mysql_free_result($result);
    
                // update the occurances of this pattern
                $query = "UPDATE ".$dbgrouptable." SET amount=amount+1 WHERE id=".$log_groupid;
                $result = mysql_query($query) or die(xml_for_result(FAILURE_SQL_UPDATE_PATTERN_OCCURANCES));
    
                // check the status of the bugfix version
                $query = "SELECT status FROM ".$dbversiontable." WHERE bundleidentifier = '".$bundleidentifier."' and version = '".$row[1]."'";
                $result = mysql_query($query) or die(xml_for_result(FAILURE_SQL_CHECK_BUGFIX_STATUS));
                
                $numrows = mysql_num_rows($result);
                if ($numrows == 1)
                {
                    $row = mysql_fetch_row($result);
                    $fix_status = $row[0];
                }
    
                if ($notify_amount_group > 1 && $notify_amount_group == $amount && $notify >= NOTIFY_ACTIVATED && $version_status != VERSION_STATUS_DISCONTINUED)
                {
                    // send push notification
                    if ($push_activated)
                    {
                        $prowl->push(array(
                            'application'=>$applicationname,
                            'event'=>'Critical Crash',
                            'description'=>'Version '.$version.' Pattern '.$crash_offset.' has a MORE than '.$notify_amount_group.' crashes!\n Sent at ' . date('H:i:s'),
                            'priority'=>0,
                        ),true);
                    }
                    
                    // send email notification
                    if ($mail_activated)
                    {
                        $subject = $applicationname.': Critical Crash';
                        
                        if ($crash_url != '')
                            $url = "Link: ".$crash_url."admin/crashes.php?bundleidentifier=".$bundleidentifier."&version=".$version."&groupid=".$log_groupid."\n\n";
                        else
                            $url = "\n";
                        $message = "Version ".$version." Pattern ".$crash_offset." has a MORE than ".$notify_amount_group." crashes!\n".$url."Sent at ".date('H:i:s');
    
                        mail($notify_emails, $subject, $message, 'From: '.$mail_from. "\r\n");
                    }
                }
    
                mysql_free_result($result);
            } else if ($numrows == 0) {
                // create a new pattern for this bug and set amount of occurrances to 1
                $query = "INSERT INTO ".$dbgrouptable." (bundleidentifier, affected, pattern, amount) values ('".$bundleidentifier."', '".$version."', '".$crash_offset."', 1)";
                $result = mysql_query($query) or die(xml_for_result(FAILURE_SQL_ADD_PATTERN));
    
                $log_groupid = mysql_insert_id($link);
    
                if ($version_status != VERSION_STATUS_DISCONTINUED && $notify == NOTIFY_ACTIVATED)
                {
                    // send push notification
                    if ($push_activated)
                    {
                        $prowl->push(array(
                            'application'=>$applicationname,
                            'event'=>'New Crash type',
                            'description'=>'Version '.$version.' has a new type of crash!\n Sent at ' . date('H:i:s'),
                            'priority'=>0,
                        ),true);
                    }
                    
                    // send email notification
                    if ($mail_activated)
                    {
                        $subject = $applicationname.': New Crash type';
    
                        if ($crash_url != '')
                            $url = "Link: ".$crash_url."admin/crashes.php?bundleidentifier=".$bundleidentifier."&version=".$version."&groupid=".$log_groupid."\n\n";
                        else
                            $url = "\n";
                        $message = "Version ".$version." has a new type of crash!\n".$url."Sent at ".date('H:i:s');
    
                        mail($notify_emails, $subject, $message, 'From: '.$mail_from. "\r\n");
                    }
                }
            }
        }
        
        // only add the data if the version is not set to discontinued
        if ($version_status != VERSION_STATUS_DISCONTINUED)
        {
            // now insert the crashlog into the database
            $query = "UPDATE ".$dbcrashtable." SET groupid=".$log_groupid." WHERE id=".$crashid;
            $result = mysql_query($query) or die(xml_for_result(FAILURE_SQL_ADD_CRASHLOG));        
        }
        
    }
	    
    mysql_free_result($result1);
}

mysql_close($link);

?>
<html>
<head>
    <META http-equiv="refresh" content="0;URL=groups.php?&bundleidentifier=<?php echo $bundleidentifier ?>&version=<?php echo $version ?>">
</head>
<body>
Redirecting...
</body>
</html>
