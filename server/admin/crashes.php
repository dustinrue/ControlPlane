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
// Shows a list of crashes for a given crash group
//
// Shows all crashes for a given crash group. You can download each crash
// from this view, or see all the relevant information about this crash
// that is available
//

require_once('../config.php');
require_once('common.inc');

init_database();
parse_parameters(',groupid,bundleidentifier,version,symbolicate,all,search,type,');

if (!isset($all)) $all = false;
if (!isset($groupid)) $groupid = "";
if (!isset($bundleidentifier)) $bundleidentifier = "";
if (!isset($version)) $version = "";
if (!isset($symbolicate)) $symbolicate = "";
if (!isset($search)) $search = "";
if (!isset($type)) $type = "";

if ($bundleidentifier == "" && ($version == "" || $type = "")) die(end_with_result('Wrong parameters'));

$whereclause = "";
$pagelink = "";
if ($search != "" && $type != "") {
	$pagelink = '?bundleidentifier='.$bundleidentifier.'&search='.$search.'&type='.$type;
	$whereclause = " WHERE bundleidentifier = '".$bundleidentifier."'";
	if ($type == SEARCH_TYPE_ID)
        $whereclause .= " AND id = '".$search."'";
    else if ($type == SEARCH_TYPE_DESCRIPTION)
        $whereclause .= " AND description like '%".$search."%'";
    else if ($type  == SEARCH_TYPE_CRASHLOG)
        $whereclause .= " AND log like '%".$search."%'";
    if ($version != "")
    	$whereclause .= " AND version = '".$version."'";
} else if ($groupid == "") {
	$pagelink = '?bundleidentifier='.$bundleidentifier.'&version='.$version;
	$whereclause = " WHERE bundleidentifier = '".$bundleidentifier."' AND version = '".$version."' AND groupid = 0";
} else {
	$pagelink = '?bundleidentifier='.$bundleidentifier.'&version='.$version.'&groupid='.$groupid;
	$whereclause = " WHERE groupid = ".$groupid;
}
if ($all) $pagelink .= "&all=true";

if ($symbolicate != '')
{
	$query = "SELECT id FROM ".$dbsymbolicatetable." WHERE crashid = ".$symbolicate;
	$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));

	$numrows = mysql_num_rows($result);
	mysql_free_result($result);

	if ($numrows > 0)
		$query = "UPDATE ".$dbsymbolicatetable." SET done = 0 WHERE crashid = ".$symbolicate;
	else
		$query = "INSERT INTO ".$dbsymbolicatetable." (crashid, done) values (".$symbolicate.", 0)";

	$result = mysql_query($query) or die('Error in SQL '.$dbsymbolicatetable);
}

show_header('- List');

$cols = '<colgroup><col width="80"/><col width="190"/><col width="500"/><col width="110"/></colgroup>';

echo '<h2>';

if (!$acceptallapps)
	echo '<a href="app_name.php">Apps</a> - ';

echo create_link($bundleidentifier, 'app_versions.php', false, 'bundleidentifier').' - ';
if ($version != "")
    echo create_link('Version '.$version, 'groups.php', false, 'bundleidentifier,version').' - ';
echo create_link('Crashes', 'crashes.php', false, $pagelink).'</h2>';

if ($search != "" || $type != "")
    show_search($search, $type);

echo '<table>'.$cols;
echo "<tr><th>System</th><th>Timestamp / Description</th><th>Log</th><th>Action</th></tr>";
echo '</table>';

// get all groups
$query = "SELECT userid, contact, systemversion, description, log, timestamp, id FROM ".$dbcrashtable.$whereclause." ORDER BY systemversion desc, timestamp desc";
if (!$all) {
	$query .= " limit ".$default_amount_crashes;
}
$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));

$numrows = mysql_num_rows($result);
if ($numrows > 0) {
	// get the status
	while ($row = mysql_fetch_row($result))
	{
		$userid = $row[0];
		$contact = $row[1];
		$systemversion = $row[2];
		$description = $row[3];
		$log = $row[4];
		$timestamp = $row[5];
		$crashid = $row[6];
		
		$description = "User: ".$userid."\nContact: ".$contact."\nDescription:\n".$description;
		
		$todo = 2;
		$query2 = "SELECT done FROM ".$dbsymbolicatetable." WHERE crashid = ".$crashid;
		$result2 = mysql_query($query2) or die(end_with_result('Error in SQL '.$query));

		$numrows2 = mysql_num_rows($result2);
		if ($numrows2 > 0)
		{
			$row2 = mysql_fetch_row($result2);
			$todo = $row2[0];
		}
		mysql_free_result($result2);
	
		if ($timestamp != "" && ($timestampvalue = strtotime($timestamp)) !== false)
		{
			if (time() - $timestampvalue < 60*24*24)
				$timestamp = "<font color='red'>".$timestamp."</font>";
			else if (time() - $timestampvalue < 60*24*24*2)
				$timestamp = "<font color='orange'>".$timestamp."</font>";
		}

		echo '<table>'.$cols;
		echo "<tr valign='top' align='center'><td>".$systemversion."</td><td>".$timestamp."<br/><textarea class='short' readonly>".$description."</textarea></td><td><textarea wrap='off' class='log' readonly>".$log."</textarea></td><td><a href='download.php?crashid=".$crashid."' class='button'>Download</a><br><br>";
		if ($todo == 0)
			echo "Symolication in progress";
		else
			echo "<a href='crashes.php".$pagelink."&symbolicate=".$crashid."' class='button'>Symbolicate</a>";
		if ($todo == 2)
			echo "<br/>(Not done!)";
		echo "</td></tr>";
		echo '</table>';
	}
	
	mysql_free_result($result);
}

if (!$all) {

	$amount = 0;
	
	if ($search != "" && $type != "")
        $query = "SELECT count(*) FROM ".$dbcrashtable.$whereclause;
    else {
    	if ($groupid == "")
    		$groupid = 0;

    	$query = "SELECT amount FROM ".$dbgrouptable." WHERE bundleidentifier = '".$bundleidentifier."' AND affected = '".$version."' and id = ".$groupid;
	}
	$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));

	$numrows = mysql_num_rows($result);
	if ($numrows == 1) {
		// get the status
		$row = mysql_fetch_row($result);
		$amount = $row[0];
	}
	
	mysql_free_result($result);

	if ($amount > $default_amount_crashes)
        echo create_link('Show all '.$amount.' entries', 'crashes.php', true, ',bundleidentifier,version,groupid,search,type,all=true');
}

echo '</body></html>';

mysql_close($link);

?>
