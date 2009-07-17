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
// This is the main admin UI script
//
// You can add applications by adding their respective bundle identifiers
// and you can delete applications and define if external symbolification
// should be turned on or not
//

require_once('../config.php');

if ($acceptallapps)
{
	die('<html><head><META http-equiv="refresh" content="0;URL=app_versions.php"></head><body></body</html>'); 
}

function end_with_result($result)
{
	return '<html><body>'.$result.'</body</html>'; 
}

$allowed_args = ',bundleidentifier,symbolicate,id,';

$link = mysql_connect($server, $loginsql, $passsql)
    or die(end_with_result('No database connection'));
mysql_select_db($base) or die(end_with_result('No database connection'));

foreach(array_keys($_GET) as $k) {
    $temp = ",$k,";
    if(strpos($allowed_args,$temp) !== false) { $$k = $_GET[$k]; }
}

if (!isset($bundleidentifier)) $bundleidentifier = "";
if (!isset($symbolicate)) $symbolicate = "";
if (!isset($id)) $id = "";

// update the app
if ($bundleidentifier != "" && $id == "" && $symbolicate != "") {
	$query = "SELECT id FROM ".$dbapptable." WHERE bundleidentifier = '".$bundleidentifier."'";
	$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));
	
	$numrows = mysql_num_rows($result);
	if ($numrows == 1)
	{
		$row = mysql_fetch_row($result);
		$query2 = "UPDATE ".$dbversiontable." SET symbolicate = ".$symbolicate." WHERE id = ".$row[0];
		$result2 = mysql_query($query2) or die(end_with_result('Error in SQL '.$query2));
	} else if ($numrows == 0) {
		// version is not available, so add it with status VERSION_STATUS_AVAILABLE
		$query2 = "INSERT INTO ".$dbapptable." (bundleidentifier, symbolicate) values ('".$bundleidentifier."', ".$symbolicate.")";
		$result2 = mysql_query($query2) or die(end_with_result('Error in SQL '.$query2));
	}
} else if ($symbolicate != "" && $id != "") {
	$query = "UPDATE ".$dbapptable." SET symbolicate = ".$symbolicate." WHERE id = ".$id;
	$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));
} else if ($id != "" && $symbolicate == "") {
	// delete a version
	$query = "DELETE FROM ".$dbapptable." WHERE id = ".$id;
	$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));
}

echo '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML  4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">';
echo '<html><head><link rel="stylesheet" type="text/css" href="body.css"></head><body>';

echo '<a href="app_name.php">Apps</a><br/><br/>';

echo '<table class="top" cellspacing="0" cellpadding="2"><colgroup><col width="400"/><col width="200"/><col width="100"/></colgroup>';
echo "<tr><th>Bundle identifier</th><th>Symbolicate</th><th>Actions</th></tr>";
echo '</table>';

// get all applications and their symbolication status
$query = "SELECT bundleidentifier, symbolicate, id FROM ".$dbapptable." ORDER BY bundleidentifier asc, symbolicate desc";
$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));

$numrows = mysql_num_rows($result);
if ($numrows > 0) {
	// get the status
	while ($row = mysql_fetch_row($result))
	{
		$bundleidentifier = $row[0];
		$symbolicate = $row[1];
		$id = $row[2];
				
		echo "<form name='update".$id."' action='app_name.php' method='get'><input type='hidden' name='id' value='".$id."'/>";
		echo '<table class="top" cellspacing="0" cellpadding="2"><colgroup><col width="400"/><col width="200"/><col width="100"/></colgroup>';

		echo "<tr align='center'><td><a href='app_versions.php?bundleidentifier=".$bundleidentifier."'>".$bundleidentifier."</a></td><td><select name='symbolicate' onchange='javascript:document.update".$id.".submit();'><option value=0";
		if ($symbolicate == 0)
			echo " selected";			
		echo ">Don't symbolicate</option><option value=1";
		if ($symbolicate == 1)
			echo " selected";
			
		echo ">Symbolicate</option></select></td>";
		
		echo "<td><a href='app_name.php?id=".$id."'>Delete</a></td>";
		echo "</tr></table></form>";
	}
	
	mysql_free_result($result);
}

mysql_close($link);

if (!$acceptallapps)
{
	echo "<form name='add_app' action='app_name.php' method='get'>";
	echo '<table class="bottom" cellspacing="0" cellpadding="2"><col width="400"/><col width="200"/><col width="100"/></colgroup>';
	
	echo "<tr align='center'><td><input type='text' name='bundleidentifier' size='30' maxlength='50'/></td><td><select name='symbolicate'><option value=0 selected>Don't symbolicate</option><option value=1>Symbolicate</option></select></td><td><input type='submit' value='Add App'/></td></tr>";
	
	echo '</table></form>';
}

echo '</body></html>';

?>
