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

include('ProwlPHP.php');

if ($push_activated && $push_prowlids != "")
	$prowl = new Prowl($push_prowlids);
else
	$push_activated = false;

function xml_for_result($result)
{
	return '<?xml version="1.0" encoding="UTF-8"?><result>'.$result.'</result>'; 
}

$allowed_args = ',xmlstring,';

/* Verbindung aufbauen, auswählen einer Datenbank */
$link = mysql_connect($server, $loginsql, $passsql)
    or die(xml_for_result(RESULT_FAILURE));
mysql_select_db($base) or die(xml_for_result(RESULT_FAILURE));

foreach(array_keys($_POST) as $k) {
    $temp = ",$k,";
    if(strpos($allowed_args,$temp) !== false) { $$k = $_POST[$k]; }
}
if (!isset($xmlstring)) $xmlstring = "";

if ($xmlstring == "") die(xml_for_result(RESULT_FAILURE));

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
		if( !ValidateString( $version, array('format'=>VALIDATE_NUM . VALIDATE_SPACE . VALIDATE_PUNCTUATION) ) ) die(xml_for_result(RESULT_FAILURE));
	} else if ($reader->name == "senderversion" && $reader->nodeType == XMLReader::ELEMENT) {
  	$senderversion = mysql_real_escape_string(reading($reader, "senderversion"));
		if (!ValidateString( $senderversion, array('format'=>VALIDATE_NUM . VALIDATE_SPACE . VALIDATE_PUNCTUATION) ) ) die(xml_for_result(RESULT_FAILURE));
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

// check out if we accept this app and version of the app
$acceptlog = false;
$symbolicate = false;

// shall we accept any crash log or only ones that are named in the database
if ($acceptallapps)
{
	// external symbolification will is turned on by default when accepting all crash logs
	$acceptlog = true;
	$symbolicate = true;
	
	// get the app name
	$query = "SELECT name FROM ".$dbapptable." where bundleidentifier = '".$bundleidentifier."'";
	$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));

	$numrows = mysql_num_rows($result);
	if ($numrows == 1) {
		$appname = $row[0];
	}
	mysql_free_result($result);
}
else
{
	// the bundleidentifier is the important string we use to find a match
	$query = "SELECT id, symbolicate, name FROM ".$dbapptable." where bundleidentifier = '".$bundleidentifier."'";
	$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));

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
	}
	mysql_free_result($result);
}


// add the crash data to the database
if ($logdata != "" && $version != "" & $applicationname != "" && $bundleidentifier != "" && $acceptlog == true)
{
	// first try to find the offset of the crashing thread to assign this crash to a crash group
	
	// this stores the offset which we need for grouping
	$crash_offset = "";
	
	// extract the block which contains the data of the crashing thread
	preg_match('%Thread [0-9]+ Crashed:\n(.*?)\n\n%s', $xmlstring, $matches);
	
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
		$result = mysql_query($query) or die(xml_for_result(RESULT_FAILURE));

		$numrows = mysql_num_rows($result);
		
		if ($numrows == 1)
		{
			// assign this bug to the group
			$row = mysql_fetch_row($result);
			$log_groupid = $row[0];
			$amount = $row[2];

			mysql_free_result($result);

			// update the occurances of this group
			$query = "UPDATE ".$dbgrouptable." SET amount=amount+1 WHERE id=".$log_groupid;
			$result = mysql_query($query) or die(xml_for_result(RESULT_FAILURE));

			// check the status of the bugfix version
			$query = "SELECT status FROM ".$dbversiontable." WHERE bundleidentifier = '".$bundleidentifier."' and version = '".$row[1]."'";
			$result = mysql_query($query) or die(xml_for_result(RESULT_FAILURE));

			$numrows = mysql_num_rows($result);
			if ($numrows == 1)
			{
				$row = mysql_fetch_row($result);
				$fix_status = $row[0];
			}
			
			if ($push_activated && $push_amount_group > 1 && $push_amount_group == $amount)
			{
				$prowl->push(array(
						'application'=>$appname,
						'event'=>'Critical Crash',
						'description'=>'Version '.$version.' Pattern '.$crash_offset.' has a MORE than '.$push_amount_group.' crashes!\n Sent at ' . date('H:i:s'),
						'priority'=>0,
      		),true);
      }

			mysql_free_result($result);
		} else if ($numrows == 0)
		{
			// create a new group for this bug and set amount of occurrances to 1
			$query = "INSERT INTO ".$dbgrouptable." (bundleidentifier, affected, pattern, amount) values ('".$bundleidentifier."', '".$version."', '".$crash_offset."', 1)";
			$result = mysql_query($query) or die(xml_for_result(RESULT_FAILURE));
			
			$log_groupid = mysql_insert_id($link);
			
			if ($push_activated && $push_newtype)
			{
				$prowl->push(array(
						'application'=>$appname,
						'event'=>'New Crashtype',
						'description'=>'Version '.$version.' has a new type of crash!\n Sent at ' . date('H:i:s'),
						'priority'=>0,
					),true);
			}
		}		
	}
	
	// check if the version is already added
	$query = "SELECT id FROM ".$dbversiontable." WHERE bundleidentifier = '".$bundleidentifier."' and version = '".$version."'";
	$result = mysql_query($query) or die(xml_for_result(RESULT_FAILURE));

	$numrows = mysql_num_rows($result);
	if ($numrows == 0) {
		// version is not available, so add it with status VERSION_STATUS_AVAILABLE
		$query = "INSERT INTO ".$dbversiontable." (bundleidentifier, version, status) values ('".$bundleidentifier."', '".$version."', ".VERSION_STATUS_UNKNOWN.")";
		$result = mysql_query($query) or die(xml_for_result(RESULT_FAILURE));
	}

	// now insert the crashlog into the database
	
	$query = "INSERT INTO ".$dbcrashtable." (userid, contact, bundleidentifier, applicationname, systemversion, senderversion, version, description, log, groupid) values ('".$userid."', '".$contact."', '".$bundleidentifier."', '".$applicationname."', '".$systemversion."', '".$senderversion."', '".$version."', '".$description."', '".$logdata."', '".$log_groupid."')";
	$result = mysql_query($query) or die(xml_for_result(RESULT_FAILURE));
	
	// if this crash log has to be manually symbolicated, add a todo entry
	if ($symbolicate)
	{
		$new_crashid = mysql_insert_id($link);

		$query = "INSERT INTO ".$dbsymbolicatetable." (crashid, done) values (".$new_crashid.", 0)";
		$result = mysql_query($query) or die(xml_for_result(RESULT_FAILURE));
	}
} else if ($acceptlog == false)
{
	mysql_close($link);
	die(xml_for_result(RESULT_FAILURE));
}
	
/* schliessen der Verbinung */
mysql_close($link);

/* Ausgabe der Ergebnisse in XML */
echo xml_for_result($fix_status);
?>
