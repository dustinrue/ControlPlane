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
// This script shows all crash groups for a version
//
// This script shows a list of all crash groups of a version of an application,
// the amount of crash logs assigned to this group and the assigned bugfix version
// You can edit the bugfix version, if this version is not added yet, it will be added
// automatically to the version list. You can also assign a short description for
// this crash group or download the latest crash log data for this group directly.
// All crashes that weren't assigned to a group, will be shown in the list with in one
// combined entry too
//

require_once('../config.php');
require_once('common.inc');

init_database();
parse_parameters(',bundleidentifier,version,fixversion,id,description,groupid,');

if (!isset($bundleidentifier)) $bundleidentifier = "";
if (!isset($version)) $version = "";
if (!isset($id)) $id = "-1";
if (!isset($groupid)) $groupid = "";
if (!isset($fixversion)) $fixversion = "-1";
if (!isset($description)) $description = "-1";

if ($bundleidentifier == "") die(end_with_result('Wrong parameters'));
if ($version == "") die(end_with_result('Wrong parameters'));

if ($id != "-1" && $id != "" && $fixversion != "-1") {
	$query = "UPDATE ".$dbgrouptable." SET fix = '".$fixversion."' WHERE id = ".$id;
	$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));
	
	// check if the fix version is alreadz added, if not add it
	$query = "SELECT id FROM ".$dbversiontable." WHERE bundleidentifier = '".$bundleidentifier."' and version = '".$fixversion."'";
	$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));
	
	$numrows = mysql_num_rows($result);
	if ($numrows == 0) {
		// version is not available, so add it with status VERSION_STATUS_AVAILABLE
		$query = "INSERT INTO ".$dbversiontable." (bundleidentifier, version, status) values ('".$bundleidentifier."', '".$fixversion."', ".VERSION_STATUS_UNKNOWN.")";
		$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));
	}
} else if ($groupid != "") {
	$query = "DELETE FROM ".$dbsymbolicatetable." WHERE crashid in (select id from ".$dbcrashtable." where groupid = ".$groupid.")";
	$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));

	$query = "DELETE FROM ".$dbcrashtable." WHERE groupid = ".$groupid;
	$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));
	
	if ($groupid != "0") {
		$query = "DELETE FROM ".$dbgrouptable." WHERE id = ".$groupid;
		$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));
	}
}

if ($id != "-1" && $id != "" && $description != "-1") {
	$query = "UPDATE ".$dbgrouptable." SET description = '".$description."' WHERE id = ".$id;
	$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));
}

if ($id == "-1") $$id = "";
if ($fixversion == "-1") $fixversion = "";
if ($description == "-1") $description = "";

show_header('- Crash Patterns');

echo '<h2>';
if (!$acceptallapps)
	echo '<a href="app_name.php">Apps</a> - ';

echo create_link($bundleidentifier, 'app_versions.php', false, 'bundleidentifier').' - '.create_link('Version '.$version, 'groups.php', false, 'bundleidentifier,version').'</h2>';

show_search("", -1);

$cols = '<colgroup><col width="90"/><col width="50"/><col width="100"/><col width="180"/><col width="360"/><col width="190"/></colgroup>';

echo '<table>'.$cols;
echo "<tr><th>Pattern</th><th>Amount</th><th>Last Update</th><th>Assigned Fix Version</th><th>Description</th><th>Actions</th></tr>";
echo '</table>';

// get all groups
$query = "SELECT fix, pattern, amount, id, description FROM ".$dbgrouptable." WHERE bundleidentifier = '".$bundleidentifier."' AND affected = '".$version."' ORDER BY fix desc, amount desc, pattern asc";
$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));

$numrows = mysql_num_rows($result);
if ($numrows > 0) {
	// get the status
	while ($row = mysql_fetch_row($result))
	{
		$fix = $row[0];
		$pattern = $row[1];
		$amount = $row[2];
		$groupid = $row[3];
		$description = $row[4];
		$lastupdate = '';
		
		// get all groups
		$query2 = "SELECT max(timestamp) FROM ".$dbcrashtable." WHERE groupid = '".$groupid."'";
		$result2 = mysql_query($query2) or die(end_with_result('Error in SQL '.$query));
		$numrows2 = mysql_num_rows($result2);
		if ($numrows2 > 0) {
			$row2 = mysql_fetch_row($result2);
			$lastupdate = $row2[0];
		}
		mysql_free_result($result2);
		
		if ($push_amount_group > 1 && $amount >= $push_amount_group)
		{
			$amount = "<b><font color='red'>".$amount."</font></b>";
		}
		
		echo "<form name='update".$groupid."' action='groups.php' method='get'><input type='hidden' name='bundleidentifier' value='".$bundleidentifier."'/><input type='hidden' name='version' value='".$version."'/><input type='hidden' name='id' value='".$groupid."'/>";
		echo '<table>'.$cols;
		echo "<tr><td><a href='crashes.php?groupid=".$groupid."&bundleidentifier=".$bundleidentifier."&version=".$version."'>".$pattern."</a></td><td>".$amount."</td><td>";
		
		if ($lastupdate != "" && ($timestamp = strtotime($lastupdate)) !== false)
		{
			if (time() - $timestamp < 60*24*24)
				$lastupdate = "<font color='".$color24h."'>".$lastupdate."</font>";
			else if (time() - $timestamp < 60*24*24*2)
				$lastupdate = "<font color='".$color48h."'>".$lastupdate."</font>";
			else if (time() - $timestamp < 60*24*24*3)
				$lastupdate = "<font color='".$color72h."'>".$lastupdate."</font>";
			else
				$lastupdate = "<font color='".$colorOther."'>".$lastupdate."</font>";
		}
		echo $lastupdate;
		
		echo "</td><td><input type='text' name='fixversion' size='20' maxlength='20' value='".$fix."'/></td><td><textarea cols='50' rows='2' name='description' class='description'>".$description."</textarea></td><td><button type='submit' class='button'>Update</button><a href='download.php?groupid=".$groupid."' class='button'>Download</a><a href='groups.php?bundleidentifier=".$bundleidentifier."&version=".$version."&groupid=".$groupid."' class='button' onclick='return confirm(\"Do you really want to delete this item?\");'>Delete</a></td></tr>";
		echo '</table>';
		echo "</form>";
	}
	
	mysql_free_result($result);
}

// get all bugs not assigned to groups
$query = "SELECT count(*) FROM ".$dbcrashtable." WHERE groupid = 0 and bundleidentifier = '".$bundleidentifier."' AND version = '".$version."'";
$result = mysql_query($query) or die(end_with_result('Error in SQL '.$dbcrashtable));

$numrows = mysql_num_rows($result);
if ($numrows > 0) {
	$row = mysql_fetch_row($result);
	$amount = $row[0];
	if ($amount > 0)
	{
        echo '<table>'.$cols;
		echo "<tr><td><a href='crashes.php?bundleidentifier=".$bundleidentifier."&version=".$version."'>Ungrouped</a></td><td>".$amount."</td><td></td><td></td><td></td><td><a href='groups.php?bundleidentifier=".$bundleidentifier."&version=".$version."&groupid=0' class='button'>Delete</td></tr>";		
		echo '</table>';
	}
	mysql_free_result($result);
}

mysql_close($link);

echo '</body></html>';

?>
