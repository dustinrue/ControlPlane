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

function end_with_result($result) {
	return '<html><body>'.$result.'</body></html>'; 
}

$link = mysql_connect($server, $loginsql, $passsql);

$con = mysql_select_db($base, $link);

$query = "ALTER TABLE ".$dbgrouptable." ADD COLUMN latesttimestamp BIGINT";
$result = mysql_query($query) or die(end_with_result('Error in SQL: '.$query));

$query = "CREATE INDEX latesttimestamp ON ".$dbgrouptable." (latesttimestamp)";
$result = mysql_query($query) or die(end_with_result('Error in SQL: '.$query));

$query = "SELECT bundleidentifier, version FROM ".$dbversiontable;
$result = mysql_query($query) or die(end_with_result('Error in SQL: '.$query));

$numrows = mysql_num_rows($result);
if ($numrows > 0) {
	// get the status
	while ($row = mysql_fetch_row($result)) {
		$bundleidentifier = $row[0];
		$version = $row[1];

    $query1 = "SELECT id, amount, latesttimestamp FROM ".$dbgrouptable." WHERE bundleidentifier = '".$bundleidentifier."' AND affected = '".$version."'";
    $result1 = mysql_query($query1) or die(end_with_result('Error in SQL: '.$query1));

    $numrows1 = mysql_num_rows($result1);
    if ($numrows1 > 0) {
    	// get the status
    	while ($row1 = mysql_fetch_row($result1)) {
    		$groupid = $row1[0];
    		$amount = $row1[1];
    		$latest = $row1[2];
    		$lastupdate = '';
		
    		if ($amount > 0 && $latest == 0) {
          $query2 = "SELECT max(UNIX_TIMESTAMP(timestamp)) FROM ".$dbcrashtable." WHERE groupid = '".$groupid."'";
          $result2 = mysql_query($query2) or die(end_with_result('Error in SQL '.$query2));
          $numrows2 = mysql_num_rows($result2);
          if ($numrows2 > 0) {
            $row2 = mysql_fetch_row($result2);
            $lastupdate = $row2[0];
          }
          mysql_free_result($result2);
            
          if ($lastupdate != '') {
            $query2 = "UPDATE ".$dbgrouptable." SET latesttimestamp = ".$lastupdate." WHERE id = ".$groupid;
            $result2 = mysql_query($query2) or die(end_with_result('Error in SQL '.$query2));
          }
    		}
      }
      mysql_free_result($result1);
    }
  }
  mysql_free_result($result);
}

mysql_close($link);

?>
<html><head></head>
<body>
Done
</body>
</html>
