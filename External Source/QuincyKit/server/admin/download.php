<?php

	/*
	 * Author: Andreas Linde <mail@andreaslinde.de>
	 *
	 * Copyright (c) 2009-2011 Andreas Linde & Kent Sutherland.
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

$allowed_args = ',groupid,crashid,';

$link = mysql_connect($server, $loginsql, $passsql)
    or die(end_with_result('No database connection'));
mysql_select_db($base) or die(end_with_result('No database connection'));

foreach(array_keys($_GET) as $k) {
    $temp = ",$k,";
    if(strpos($allowed_args,$temp) !== false) { $$k = $_GET[$k]; }
}

if (!isset($groupid)) $groupid = "";
if (!isset($crashid)) $crashid = "";

if ($groupid == "" && $crashid == "") die(end_with_result('Wrong parameters'));

$query = "";
if ($groupid != "") {
	$query = "SELECT userid, contact, systemversion, description, log, timestamp FROM ".$dbcrashtable." WHERE groupid = '".$groupid."' ORDER BY systemversion desc, timestamp desc LIMIT 1";
} else {
	$query = "SELECT userid, contact, systemversion, description, log, timestamp FROM ".$dbcrashtable." WHERE id = '".$crashid."' ORDER BY systemversion desc, timestamp desc LIMIT 1";
}
$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));

$numrows = mysql_num_rows($result);
if ($numrows > 0) {
	// get the status
	$row = mysql_fetch_row($result);
	$userid = $row[0];
	$contact = $row[1];
	$systemversion = $row[2];
	$description = $row[3];
	$log = $row[4];
	$timestamp = $row[5];
	
	// We'll be outputting a text file
	header('Content-type: application/text');

	// It will be called abc.txt
	header('Content-Disposition: attachment; filename="'.$timestamp.'.crash"');
	echo $log;
	
	mysql_free_result($result);
} else {
	echo '<html><head></head><body>Nothing found!</body></html>';
}

mysql_close($link);

?>
