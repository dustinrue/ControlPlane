<?php

	/*
	 * Author: Andreas Linde <mail@andreaslinde.de>
	 *         Kenth Sutherland
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
// This script will be invoked by the application to submit a crash log
//

require_once('config.php');

if ($push_activated && $push_prowlids != "") {
	include('ProwlPHP.php');

	$prowl = new Prowl($push_prowlids);
} else {
	$push_activated = false;
}

function xml_for_result($result)
{
	return '<?xml version="1.0" encoding="UTF-8"?><result>'.$result.'</result>'; 
}

$allowed_args = ',xmlstring,';

/* Verbindung aufbauen, auswählen einer Datenbank */
$link = mysql_connect($server, $loginsql, $passsql)
    or die(xml_for_result(FAILURE_DATABASE_NOT_AVAILABLE));
mysql_select_db($base) or die(xml_for_result(FAILURE_DATABASE_NOT_AVAILABLE));

foreach(array_keys($_POST) as $k) {
    $temp = ",$k,";
    if(strpos($allowed_args,$temp) !== false) { $$k = $_POST[$k]; }
}
if (!isset($xmlstring)) $xmlstring = "";

if ($xmlstring == "") die(xml_for_result(FAILURE_INVALID_POST_DATA));

$reader = new XMLReader();

$reader->XML($xmlstring);

$bundleidentifier = "";
$applicationname = "";
$systemversion = "";
$senderversion = "";
$version = "";
$userid = "";
$contact = "";
$description = "";
$logdata = "";
$appname = "";


function reading($reader, $tag)
{
  $input = "";
	while ($reader->read())
	{
    if ($reader->nodeType == XMLReader::TEXT
        || $reader->nodeType == XMLReader::CDATA
        || $reader->nodeType == XMLReader::WHITESPACE
        || $reader->nodeType == XMLReader::SIGNIFICANT_WHITESPACE)
    {
      $input .= $reader->value;
    }
    else if ($reader->nodeType == XMLReader::END_ELEMENT
        && $reader->name == $tag)
    {
      break;
    }
  }
	return $input;
}

define('VALIDATE_NUM',          '0-9');
define('VALIDATE_ALPHA_LOWER',  'a-z');
define('VALIDATE_ALPHA_UPPER',  'A-Z');
define('VALIDATE_ALPHA',        VALIDATE_ALPHA_LOWER . VALIDATE_ALPHA_UPPER);
define('VALIDATE_SPACE',        '\s');
define('VALIDATE_PUNCTUATION',  VALIDATE_SPACE . '\.,;\:&"\'\?\!\(\)');


/**
 * Validate a string using the given format 'format'
 *
 * @param string $string  String to validate
 * @param array  $options Options array where:
 *                          'format' is the format of the string
 *                              Ex:VALIDATE_NUM . VALIDATE_ALPHA (see constants)
 *                          'min_length' minimum length
 *                          'max_length' maximum length
 *
 * @return boolean true if valid string, false if not
 *
 * @access public
 */
function ValidateString($string, $options)
{
	$format     = null;
	$min_length = 0;
	$max_length = 0;
	
	if (is_array($options)) {
		extract($options);
	}
	
	if ($format && !preg_match("|^[$format]*\$|s", $string)) {
		return false;
	}
	
	if ($min_length && strlen($string) < $min_length) {
		return false;
	}
	
	if ($max_length && strlen($string) > $max_length) {
		return false;
	}
	
	return true;
}

while ($reader->read())
{
	if ($reader->name == "bundleidentifier" && $reader->nodeType == XMLReader::ELEMENT)
	{
		$bundleidentifier = mysql_real_escape_string(reading($reader, "bundleidentifier"));
	} else if ($reader->name == "version" && $reader->nodeType == XMLReader::ELEMENT) {
        $version = mysql_real_escape_string(reading($reader, "version"));
		if( !ValidateString( $version, array('format'=>VALIDATE_NUM . VALIDATE_ALPHA. VALIDATE_SPACE . VALIDATE_PUNCTUATION) ) ) die(xml_for_result(FAILURE_XML_VERSION_NOT_ALLOWED));
	} else if ($reader->name == "senderversion" && $reader->nodeType == XMLReader::ELEMENT) {
        $senderversion = mysql_real_escape_string(reading($reader, "senderversion"));
    if (!ValidateString( $senderversion, array('format'=>VALIDATE_NUM . VALIDATE_ALPHA. VALIDATE_SPACE . VALIDATE_PUNCTUATION) ) ) die(xml_for_result(FAILURE_XML_SENDER_VERSION_NOT_ALLOWED));
	} else if ($reader->name == "applicationname" && $reader->nodeType == XMLReader::ELEMENT) {
		$applicationname = mysql_real_escape_string(reading($reader, "applicationname"));
	} else if ($reader->name == "systemversion" && $reader->nodeType == XMLReader::ELEMENT) {
		$systemversion = mysql_real_escape_string(reading($reader, "systemversion"));
	} else if ($reader->name == "userid" && $reader->nodeType == XMLReader::ELEMENT) {
		$userid = mysql_real_escape_string(reading($reader, "userid"));
	} else if ($reader->name == "contact" && $reader->nodeType == XMLReader::ELEMENT) {
        $contact = mysql_real_escape_string(reading($reader, "contact"));
	} else if ($reader->name == "description" && $reader->nodeType == XMLReader::ELEMENT) {
		$description = mysql_real_escape_string(reading($reader, "description"));
	} else if ($reader->name == "log" && $reader->nodeType == XMLReader::ELEMENT) {
		$logdata = mysql_real_escape_string(reading($reader, "log"));
	}
}

$reader->close();

// don't proceed if we don't have anything to search for
if ($bundleidentifier == "")
	die("No valid data entered!");
	
// by default set the appname to bundleidentifier, so it has some meaningful value for sure
$appname = $bundleidentifier;

// store the status of the fix version for this crash
$fix_status = VERSION_STATUS_UNKNOWN;

// the status of the buggy version
$version_status = VERSION_STATUS_UNKNOWN;

// by default assume push is turned of for the found version
$notify = $notify_default_version;

// push ids to send notifications to (per app setting)
$notify_pushids = '';

// email addresses to send notifications to (per app setting)
$notify_emails = '';

// Check for mail code injection
foreach($_REQUEST as $fields => $value)
{
    if (eregi("TO:", $value) || eregi("CC:", $value) || eregi("CCO:", $value) || eregi("Content-Type", $value))
    {
        $mail_activated = false;
    }
}
    
// check out if we accept this app and version of the app
$acceptlog = false;
$symbolicate = false;

// shall we accept any crash log or only ones that are named in the database
if ($acceptallapps)
{
	// external symbolification is turned on by default when accepting all crash logs
	$acceptlog = true;
	$symbolicate = true;
	
	// get the app name
	$query = "SELECT name FROM ".$dbapptable." where bundleidentifier = '".$bundleidentifier."'";
	$result = mysql_query($query) or die(xml_for_result(FAILURE_SQL_SEARCH_APP_NAME));

	$numrows = mysql_num_rows($result);
	if ($numrows == 1) {
		$appname = $row[0];
		$notify_emails = $mail_addresses;
		$notify_pushids = $push_prowlids;
	}
	mysql_free_result($result);
}
else
{
	// the bundleidentifier is the important string we use to find a match
	$query = "SELECT id, symbolicate, name, notifyemail, notifypush FROM ".$dbapptable." where bundleidentifier = '".$bundleidentifier."'";
	$result = mysql_query($query) or die(xml_for_result(FAILURE_SQL_SEARCH_APP_NAME));

	$numrows = mysql_num_rows($result);
	if ($numrows == 1) {
		// we found one, so let this crash through
		$acceptlog = true;
		
		$row = mysql_fetch_row($result);
		
		// check if a todo entry shall be added to create remote symbolification
		if ($row[1] == 1)
			$symbolicate = true;
			
		// get the app name
		$appname = $row[2];
			
		$notify_emails = $row[3];
		$notify_pushids = $row[4];

	}
	
    // add global email addresses
	if ($mail_addresses != '') {
        if ($notify_emails != '') {
            $notify_emails .= ';'.$mail_addresses;
        } else {
            $notify_emails = $mail_addresses;
        }
    }
    
    // add global prowl ids
	if ($push_prowlids != '') {
        if ($notify_pushids != '') {
            $notify_pushids .= ','.$push_prowlids;
        } else {
            $notify_pushids = $push_prowlids;
        }
    }
            
	mysql_free_result($result);
}

// Make sure we only have a max of 5 prowl ids
$push_array = split(',', $notify_pushids, 6);
if (sizeof($push_array) > 5) {
    $notify_pushids = '';
    for ($i=0; $i < 5; $i++)
    {
        if (i>0)
            $notify_pushids .= ',';
        $notify_pushids .= $push_array[$i];
    }
}


// add the crash data to the database
if ($logdata != "" && $version != "" & $applicationname != "" && $bundleidentifier != "" && $acceptlog == true)
{
    // Since analyzing the log data seems to have problems, first add it to the database, then read it, since it seems that one is fine then

    // first check if the version status is not discontinued
    
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

	if ($version_status == VERSION_STATUS_DISCONTINUED)
	{
    	mysql_close($link);
    	die(xml_for_result(FAILURE_VERSION_DISCONTINUED));
	}

    // now insert the crashlog into the database
	$query = "INSERT INTO ".$dbcrashtable." (userid, contact, bundleidentifier, applicationname, systemversion, senderversion, version, description, log, groupid) values ('".$userid."', '".$contact."', '".$bundleidentifier."', '".$applicationname."', '".$systemversion."', '".$senderversion."', '".$version."', '".$description."', '".$logdata."', '0')";
	$result = mysql_query($query) or die(xml_for_result(FAILURE_SQL_ADD_CRASHLOG));
	
	$new_crashid = mysql_insert_id($link);

    // now read the crashlog again and process
    $query = "SELECT log FROM ".$dbcrashtable." WHERE id = '".$new_crashid."'";
	$result = mysql_query($query) or die(xml_for_result(FAILURE_SQL_CHECK_VERSION_EXISTS));

	$numrows = mysql_num_rows($result);
		
	if ($numrows == 1)
	{
		// assign this bug to the group
		$row = mysql_fetch_row($result);
        $logdata = $row[0];
		mysql_free_result($result);
    }
    
    // now try to find the offset of the crashing thread to assign this crash to a crash group
	
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

			if ($notify_amount_group > 1 && $notify_amount_group == $amount && $notify >= NOTIFY_ACTIVATED)
			{
                // send push notification
                if ($push_activated)
                {
                    $prowl->push(array(
						'application'=>$appname,
						'event'=>'Critical Crash',
						'description'=>'Version '.$version.' Pattern '.$crash_offset.' has a MORE than '.$notify_amount_group.' crashes!\n Sent at ' . date('H:i:s'),
						'priority'=>0,
                    ),true);
                }
                
                // send email notification
                if ($mail_activated)
                {
                    $subject = $appname.': Critical Crash';
                    
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

			if ($notify == NOTIFY_ACTIVATED)
			{
                // send push notification
                if ($push_activated)
			    {
                    $prowl->push(array(
						'application'=>$appname,
						'event'=>'New Crash type',
						'description'=>'Version '.$version.' has a new type of crash!\n Sent at ' . date('H:i:s'),
						'priority'=>0,
					),true);
				}
				
                // send email notification
                if ($mail_activated)
                {
                    $subject = $appname.': New Crash type';

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
	
	// now insert the crashlog into the database
	$query = "UPDATE ".$dbcrashtable." set log = '".$logdata."', groupid = '".$log_groupid."' WHERE ID = '".$new_crashid."'";
	$result = mysql_query($query) or die(xml_for_result(FAILURE_SQL_ADD_CRASHLOG));
	
	// if this crash log has to be manually symbolicated, add a todo entry
	if ($symbolicate)
	{
		$query = "INSERT INTO ".$dbsymbolicatetable." (crashid, done) values (".$new_crashid.", 0)";
		$result = mysql_query($query) or die(xml_for_result(FAILURE_SQL_ADD_SYMBOLICATE_TODO));
	}
} else if ($acceptlog == false)
{
	mysql_close($link);
	die(xml_for_result(FAILURE_INVALID_INCOMING_DATA));
}
	
/* schliessen der Verbinung */
mysql_close($link);

/* Ausgabe der Ergebnisse in XML */
echo xml_for_result($fix_status);
?>
