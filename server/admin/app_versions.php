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
// This script shows all available versions for an application
//
// You can add versions, change the status of a version (which corresponds
// to the bugfix status), see how many crash groups are created for this
// version and how many crash reports in total are available
// If a version has no crash reports assigned, and no crash group
// has this version assigned as a bugfix version, this script also provides
// the possibility to delete the version
//

require_once('../config.php');

function end_with_result($result)
{
	return '<html><body>'.$result.'</body></html>'; 
}

$allowed_args = ',bundleidentifier,version,status,symbolicate,id,push,';

$link = mysql_connect($server, $loginsql, $passsql)
    or die(end_with_result('No database connection'));
mysql_select_db($base) or die(end_with_result('No database connection'));

foreach(array_keys($_GET) as $k) {
    $temp = ",$k,";
    if(strpos($allowed_args,$temp) !== false) { $$k = $_GET[$k]; }
}

if (!isset($bundleidentifier)) $bundleidentifier = "";
if (!isset($version)) $version = "";
if (!isset($status)) $status = "";
if (!isset($id)) $id = "";
if (!isset($push)) $push = PUSH_OFF;
if (!isset($symbolicate)) $symbolicate = 0;

// add the new app & version
if ($bundleidentifier != "" && $status != "" && $id == "" && $version != "") {
	$query = "SELECT id FROM ".$dbversiontable." WHERE bundleidentifier = '".$bundleidentifier."' and version = '".$row[1]."'";
	$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));
	
	$numrows = mysql_num_rows($result);
	if ($numrows == 1)
	{
		$row = mysql_fetch_row($result);
		$query2 = "UPDATE ".$dbversiontable." SET status = ".$status." WHERE id = ".$row[0];
		$result2 = mysql_query($query2) or die(end_with_result('Error in SQL '.$query2));
	} else if ($numrows == 0) {
		// version is not available, so add it with status VERSION_STATUS_AVAILABLE
		$query2 = "INSERT INTO ".$dbversiontable." (bundleidentifier, version, status) values ('".$bundleidentifier."', '".$version."', ".$status.")";
		$result2 = mysql_query($query2) or die(end_with_result('Error in SQL '.$query2));
	}
	mysql_free_result($result);
} else if ($id != "" && ($status != "" || $push != "")) {
	$query = "UPDATE ".$dbversiontable." SET status = ".$status.", push = ".$push." WHERE id = ".$id;
	$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));
} else if ($id != "" && $status == "") {
	// delete a version
	$query = "DELETE FROM ".$dbversiontable." WHERE id = '".$id."'";
	$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));
}

echo '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML  4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">';
echo '<html><head><link rel="stylesheet" type="text/css" href="body.css"></head><body>';

if ($acceptallapps)
	echo '<a href="app_versions.php">Versions</a><br/><br/>';
else
	echo '<a href="app_name.php">Apps</a> - <a href="app_versions.php?bundleidentifier='.$bundleidentifier.'">'.$bundleidentifier.'</a><br/><br/>';

echo '<table class="top" cellspacing="0" cellpadding="2"><colgroup><col width="400"/><col width="100"/><col width="200"/><col width="80"/><col width="100"/><col width="100"/><col width="100"/></colgroup>';
echo "<tr><th>Name</th><th>Version</th><th>Status</th><th>Push</th><th>Groups</th><th>Total Crashes</th><th>Actions</th></tr>";
echo '</table>';

// get all applications and their versions, amount of groups and amount of total bug reports
if ($acceptallapps)
	$query = "SELECT bundleidentifier, version, status, push, id FROM ".$dbversiontable." ORDER BY bundleidentifier asc, version desc, status desc";
else
	$query = "SELECT bundleidentifier, version, status, push, id FROM ".$dbversiontable." WHERE bundleidentifier = '".$bundleidentifier."' ORDER BY bundleidentifier asc, version desc, status desc";

$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));

$numrows = mysql_num_rows($result);
if ($numrows > 0) {
	// get the status
	while ($row = mysql_fetch_row($result))
	{
		$bundleidentifier = $row[0];
		$version = $row[1];
		$status = $row[2];
		$push = $row[3];
		$id = $row[4];
		$groups = 0;
		$totalcrashes = 0;
		
		// get the number of groups
		$query2 = "SELECT count(*) FROM ".$dbgrouptable." WHERE bundleidentifier = '".$bundleidentifier."' and affected = '".$version."'";
		$result2 = mysql_query($query2) or die(end_with_result('Error in SQL '.$$query2));
		
		$numrows2 = mysql_num_rows($result2);
		if ($numrows2 > 0) {
			$row2 = mysql_fetch_row($result2);
			$groups = $row2[0];
			
			mysql_free_result($result2);
		}

		// get the total number of crashes
		$query2 = "SELECT count(*) FROM ".$dbcrashtable." WHERE bundleidentifier = '".$bundleidentifier."' and version = '".$version."'";
		$result2 = mysql_query($query2) or die(end_with_result('Error in SQL '.$query2));
		
		$numrows2 = mysql_num_rows($result2);
		if ($numrows2 > 0) {
			$row2 = mysql_fetch_row($result2);
			$totalcrashes = $row2[0];
			
			mysql_free_result($result2);
		}
		
		echo "<form name='update".$id."' action='app_versions.php' method='get'><input type='hidden' name='id' value='".$id."'/><input type='hidden' name='bundleidentifier' value='".$bundleidentifier."'/>";
		echo '<table class="bottom" cellspacing="0" cellpadding="2"><colgroup><col width="400"/><col width="100"/><col width="200"/><col width="80"/><col width="100"/><col width="100"/><col width="100"/></colgroup>';


		echo "<tr align='center'><td>".$bundleidentifier."</td><td>";
		
		if ($groups > 0 || $totalcrashes > 0)
			echo "<a href='groups.php?bundleidentifier=".$bundleidentifier."&version=".$version."'>".$version."</a>";
		else
			echo $version;	
		echo "</td><td><select name='status' onchange='javascript:document.update".$id.".submit();'>";
		
		for ($i=0; $i < count($statusversions); $i++)
		{
			echo "<option value='".$i."'";
			
			if ($i == $status)
				echo " selected ";
				
			echo ">".$statusversions[$i]."</option>";
		}
		echo "</select>";
		
		echo "</td><td>";
		if ($push_activated) {
			echo "<select name='push' onchange='javascript:document.update".$id.".submit();'>";
		
			echo "<option value='".PUSH_OFF."'";
			if ($push == 0)
				echo " selected ";				
			echo ">OFF</option>";
			echo "<option value='".PUSH_ACTIVATED."'";
			if ($push == 1)
				echo " selected ";				
			echo ">ALL</option>";
			echo "<option value='".PUSH_ACTIVATED_AMOUNT."'";
			if ($push == 2)
				echo " selected ";				
			echo ">&gt; ".$push_amount_group."</option>";
			
			echo "</select>";
		} else {
			echo "<input type='hidden' name='push' value='".PUSH_OFF."'/>";
		}
		
		echo "</td><td>".$groups."</td><td>".$totalcrashes."</td><td>";
		
		if ($totalcrashes == 0 && $groups == 0)
		{
			// only show delete button if this version is nowwhere assigned as fix version
			$query2 = "SELECT count(*) FROM ".$dbgrouptable." WHERE bundleidentifier = '".$bundleidentifier."' and fix = '".$version."'";
			$result2 = mysql_query($query2) or die(end_with_result('Error in SQL '.$query2));
			$numrows2 = mysql_num_rows($result2);
			if ($numrows2 > 0) {
				$row2 = mysql_fetch_row($result2);
				if ($row2[0] == 0)
				{
					echo " <a href='app_versions.php?id=".$id."&bundleidentifier=".$bundleidentifier."'>Delete</a>";
				}
				
				mysql_free_result($result2);
			}
		}
		echo "</td></tr></table></form>";
	}
	
	mysql_free_result($result);
}

mysql_close($link);

echo "<form name='add_version' action='app_versions.php' method='get'>";
if (!$acceptallapps)
	echo "<input type='hidden' name='bundleidentifier' value='".$bundleidentifier."'/>";

echo '<table class="bottom" cellspacing="0" cellpadding="2"><colgroup><col width="400"/><col width="100"/><col width="200"/><col width="80"/><col width="200"/><col width="100"/></colgroup>';

echo "<tr align='center'><td>";

if ($acceptallapps)
	echo "<input type='text' name='bundleidentifier' size='30' maxlength='50'/>";
else
	echo $bundleidentifier;

echo "</td><td><input type='text' name='version' size='10' maxlength='20'/></td><td><select name='status'>";

for ($i=0; $i < count($statusversions); $i++)
{
	echo "<option value='".$i."'>".$statusversions[$i]."</option>";
}
echo "</select></td><td>";

if ($push_activated) {
	echo "<select name='push' onchange='javascript:document.update".$id.".submit();'>";
		
	echo "<option value='".PUSH_OFF."'";
	if ($push_default_version == PUSH_OFF)
		echo " selected ";
	echo ">OFF</option>";
	echo "<option value='".PUSH_ACTIVATED."'";
	if ($push_default_version == PUSH_ACTIVATED)
		echo " selected ";
	echo ">ALL</option>";
	echo "<option value='".PUSH_ACTIVATED_AMOUNT."'";
	if ($push_default_version == PUSH_ACTIVATED_AMOUNT)
		echo " selected ";
	echo ">&gt; ".$push_amount_group."</option>";
			
	echo "</select>";
} else {
	echo "<input type='hidden' name='push' value='".PUSH_OFF."'/>";
}

echo "</td><td><br/></td><td><input type='submit' value='Add Version'/></td></tr>";

echo '</table></form>';

echo '</body></html>';

?>
