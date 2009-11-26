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
require_once('common.inc');

if ($acceptallapps)
{
	die('<html><head><META http-equiv="refresh" content="0;URL=app_versions.php"></head><body></body></html>'); 
}

init_database();
parse_parameters(',bundleidentifier,symbolicate,id,name,issuetrackerurl,');

if (!isset($bundleidentifier)) $bundleidentifier = "";
if (!isset($symbolicate)) $symbolicate = "";
if (!isset($id)) $id = "";
if (!isset($name)) $name = "";
if (!isset($issuetrackerurl)) $issuetrackerurl = "";

$query = "";
// update the app
if ($id != "" && $symbolicate != "") {
	$query = "UPDATE ".$dbapptable." SET symbolicate = ".$symbolicate.", name = '".$name."', issuetrackerurl = '".$issuetrackerurl."' WHERE id = ".$id;
} else if ($bundleidentifier != "" && $id == "" && $symbolicate != "") {
	// insert new app
	// version is not available, so add it with status VERSION_STATUS_AVAILABLE
	$query = "INSERT INTO ".$dbapptable." (bundleidentifier, name, symbolicate, issuetrackerurl) values ('".$bundleidentifier."', '".$name."', ".$symbolicate.", '".$issuetrackerurl."')";
} else if ($symbolicate != "" && $id != "") {
	$query = "UPDATE ".$dbapptable." SET symbolicate = ".$symbolicate." WHERE id = ".$id;
} else if ($id != "" && $symbolicate == "") {
	// delete a version
	$query = "DELETE FROM ".$dbapptable." WHERE id = ".$id;
}
if ($query != "")
	$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));

show_header('- Apps');

echo '<h2><a href="app_name.php">Apps</a></h2>';

$cols = '<colgroup><col width="300"/><col width="200"/><col width="200"/><col width="150"/></colgroup>';
echo '<table>'.$cols;
echo "<tr><th>Bundle identifier</th><th>Name / Issue Tracker</th><th>Symbolicate</th><th>Actions</th></tr>";
echo '</table>';

if (!$acceptallapps)
{
	echo "<form name='add_app' action='app_name.php' method='get'>";
	echo '<table>'.$cols;
	
	echo "<tr align='center'><td><input type='text' name='bundleidentifier' size='25' maxlength='50'/></td><td><input type='text' name='name' size='25' maxlength='250'/><br/><input type='text' name='issuetrackerurl' size='25' maxlength='4000' placeholder='%subject% %description%'/></td><td><select name='symbolicate'><option value=0 selected>Don't symbolicate</option><option value=1>Symbolicate</option></select></td><td><button type='submit' class='button'>Create new App</button></td></tr>";

	
	echo '</table></form>';
}

// get all applications and their symbolication status
$query = "SELECT bundleidentifier, symbolicate, id, name, issuetrackerurl FROM ".$dbapptable." ORDER BY bundleidentifier asc, symbolicate desc";
$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));

$numrows = mysql_num_rows($result);
if ($numrows > 0) {
	// get the status
	while ($row = mysql_fetch_row($result))
	{
		$bundleidentifier = $row[0];
		$symbolicate = $row[1];
		$id = $row[2];
		$name = $row[3];
		$issuetrackerurl = $row[4];
		
		echo "<form name='update".$id."' action='app_name.php' method='get'><input type='hidden' name='id' value='".$id."'/>";
		echo '<table>'.$cols;

		echo "<tr align='center'><td><a href='app_versions.php?bundleidentifier=".$bundleidentifier."'>".$bundleidentifier."</a></td>";
		echo "<td><input type='text' name='name' size='25' maxlength='250' value='".$name."'/><br/><input type='text' name='issuetrackerurl' size='25' maxlength='4000' value='".$issuetrackerurl."' placeholder='%subject% %description%'/></td>";
		echo "<td><select name='symbolicate' onchange='javascript:document.update".$id.".submit();'>";
        add_option("Don't symbolicate", 0, $symbolicate);
        add_option('Symbolicate', 1, $symbolicate);			
		echo "</select></td>";
		
		echo "<td><button class='button' type='submit'>Update</button>";
		echo " <a href='app_name.php?id=".$id."' class='button' onclick='return confirm(\"Do you really want to delete this item?\");'>Delete</a></td>";
		echo "</tr></table></form>";
	}
	
	mysql_free_result($result);
}

mysql_close($link);

echo '</body></html>';

?>
