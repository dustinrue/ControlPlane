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
require_once('common.inc');

init_database();
parse_parameters(',bundleidentifier,version,status,symbolicate,id,notify,deletecrashes,');

if (!isset($bundleidentifier)) $bundleidentifier = "";
if (!isset($version)) $version = "";
if (!isset($status)) $status = "";
if (!isset($id)) $id = "";
if (!isset($notify)) $notify = NOTIFY_OFF;
if (!isset($symbolicate)) $symbolicate = 0;
if (!isset($deletecrashes)) $deletecrashes = -1;

// add the new app & version
if ($version != "" && $deletecrashes == "1") {
	$query = "DELETE FROM ".$dbsymbolicatetable." WHERE crashid in (select id from ".$dbcrashtable." where bundleidentifier = '".$bundleidentifier."' and version = '".$version."')";
	$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));

	$query = "DELETE FROM ".$dbcrashtable." WHERE bundleidentifier = '".$bundleidentifier."' and version = '".$version."'";
	$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));
	
    $query = "DELETE FROM ".$dbgrouptable." WHERE bundleidentifier = '".$bundleidentifier."' and affected = '".$version."'";
    $result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));
} else if ($bundleidentifier != "" && $status != "" && $id == "" && $version != "") {
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
} else if ($id != "" && ($status != "" || $notify != "")) {
	$query = "UPDATE ".$dbversiontable." SET status = ".$status.", notify = ".$notify." WHERE id = ".$id;
	$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));
} else if ($id != "" && $status == "") {
	// delete a version
	$query = "DELETE FROM ".$dbversiontable." WHERE id = '".$id."'";
	$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));
}

show_header('- App Versions');

if ($acceptallapps)
	echo '<h2><a href="app_versions.php">Versions</a></h2>';
else
	echo '<h2><a href="app_name.php">Apps</a> - '.create_link($bundleidentifier, 'app_versions.php', false, 'bundleidentifier').'</h2>';

$osticks = "";
$osvalues = "";

$crashvaluesarray = array();
$crashvalues = "";

$cols2 = '<colgroup><col width="320"/><col width="320"/><col width="320"/></colgroup>';
echo '<table>'.$cols2.'<tr><th>Platform Overview</th><th>Crashes over time</th><th>System OS Overview</th></tr>';

echo "<tr><td><div id=\"platformdiv\" style=\"height:280px;width:310px; \"></div></td>";
echo "<td><div id=\"crashdiv\" style=\"height:280px;width:310px; \"></div></td>";
echo "<td><div id=\"osdiv\" style=\"height:280px;width:310px; \"></div></td></tr>"; 

// get the amount of crashes per system version
$crashestime = true;

$query = "SELECT timestamp FROM ".$dbcrashtable."  WHERE bundleidentifier = '".$bundleidentifier."' ORDER BY timestamp desc";
$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));
$numrows = mysql_num_rows($result);
if ($numrows > 0) {
    while ($row = mysql_fetch_row($result)) {
        $timestamp = $row[0];
        
        if ($timestamp != "" && ($timestampvalue = strtotime($timestamp)) !== false)
		{
            $timeindex = substr($timestamp, 0, 10);

            if (!array_key_exists($timeindex, $crashvaluesarray)) {
                $crashvaluesarray[$timeindex] = 0;
            }
            $crashvaluesarray[$timeindex]++;
        }
    }
}
mysql_free_result($result);


$osticks = "";
$osvalues = "";
$query2 = "SELECT systemversion, COUNT(systemversion) FROM ".$dbcrashtable.$whereclause." WHERE bundleidentifier = '".$bundleidentifier."' group by systemversion order by systemversion desc";
$result2 = mysql_query($query2) or die(end_with_result('Error in SQL '.$query2));
$numrows2 = mysql_num_rows($result2);
if ($numrows2 > 0) {
	// get the status
	while ($row2 = mysql_fetch_row($result2)) {
		if ($osticks != "") $osticks = $osticks.", ";
		$osticks .= "'".$row2[0]."'";
		if ($osvalues != "") $osvalues = $osvalues.", ";
		$osvalues .= $row2[1];
	}
}
mysql_free_result($result2);

// get the amount of crashes per system version
$crashestime = true;

$platformticks = "";
$platformvalues = "";
$query = "SELECT platform, COUNT(platform) FROM ".$dbcrashtable." WHERE bundleidentifier = '".$bundleidentifier."' AND platform != \"\" group by platform order by platform desc";
$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));
$numrows = mysql_num_rows($result);
if ($numrows > 0) {
	// get the status
	while ($row = mysql_fetch_row($result)) {
		if ($platformticks != "") $platformticks = $platformticks.", ";
		$platformticks .= "'".mapPlatform($row[0])."'";
		if ($platformvalues != "") $platformvalues = $platformvalues.", ";
		$platformvalues .= $row[1];
	}
}
mysql_free_result($result);

echo '</table>';

$cols2 = '<colgroup><col width="950"/></colgroup>';
echo '<table>'.$cols2.'<tr><th>Group Details</th></tr>';
echo '<tr><td>';
            
show_search("", -1, true, "");

echo '</tr></td></table>';


$cols = '<colgroup><col width="220"/><col width="80"/><col width="120"/><col width="80"/><col width="80"/><col width="80"/><col width="160"/></colgroup>';
echo '<table>'.$cols;
echo "<tr><th>Name</th><th>Version</th><th>Status</th><th>Notify</th><th>Groups</th><th>Total Crashes</th><th>Actions</th></tr>";
echo '</table>';

echo "<form name='add_version' action='app_versions.php' method='get'>";
if (!$acceptallapps)
	echo "<input type='hidden' name='bundleidentifier' value='".$bundleidentifier."'/>";

echo '<table>'.$cols;

echo "<tr align='center'><td>";

if ($acceptallapps)
	echo "<input type='text' name='bundleidentifier' size='25' maxlength='50'/>";
else
	echo $bundleidentifier;

echo "</td><td><input type='text' name='version' size='7' maxlength='20'/></td><td><select name='status'>";

for ($i=0; $i < count($statusversions); $i++)
{
    add_option($statusversions[$i], $i, -1);
}
echo "</select></td><td>";

if ($push_activated || $mail_activated) {
	echo "<select name='notify' onchange='javascript:document.update".$id.".submit();'>";
    add_option('OFF', NOTIFY_OFF, $notify_default_version);
    add_option('ALL', NOTIFY_ACTIVATED, $notify_default_version);
    add_option('&gt; '.$notify_amount_group, NOTIFY_ACTIVATED_AMOUNT, $notify_default_version);		
	echo "</select>";
} else {
	echo "<input type='hidden' name='notify' value='".NOTIFY_OFF."'/>";
}

echo "</td><td><br/></td><td><br/></td><td><button type='submit' class='button'>Add Version</button></td></tr>";

echo '</table></form>';

// get all applications and their versions, amount of groups and amount of total bug reports
if ($acceptallapps)
	$query = "SELECT bundleidentifier, version, status, notify, id FROM ".$dbversiontable." ORDER BY bundleidentifier asc, version desc, status desc";
else
	$query = "SELECT bundleidentifier, version, status, notify, id FROM ".$dbversiontable." WHERE bundleidentifier = '".$bundleidentifier."' ORDER BY bundleidentifier asc, version desc, status desc";

$result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));

$numrows = mysql_num_rows($result);
if ($numrows > 0) {
	// get the status
	while ($row = mysql_fetch_row($result))
	{
		$bundleidentifier = $row[0];
		$version = $row[1];
		$status = $row[2];
		$notify = $row[3];
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
		echo '<table>'.$cols;

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
		if ($push_activated || $mail_activated) {
			echo "<select name='notify' onchange='javascript:document.update".$id.".submit();'>";
		    add_option('OFF', NOTIFY_OFF, $notify);
            add_option('ALL', NOTIFY_ACTIVATED, $notify);
            add_option('&gt; '.$notify_amount_group, NOTIFY_ACTIVATED_AMOUNT, $notify);					
			echo "</select>";
		} else {
			echo "<input type='hidden' name='notify' value='".NOTIFY_OFF."'/>";
		}
		
		echo "</td><td>".$groups."</td><td>".$totalcrashes."</td><td>";
		
		if ($totalcrashes == 0 && $groups == 0)
		{
			// only show delete button if this version is nowwhere assigned as fix version
			$query2 = "SELECT count(*) FROM ".$dbgrouptable." WHERE bundleidentifier = '".$bundleidentifier."' and fix = '".$version."'";
			$result2 = mysql_query($query2) or die(end_with_result('Error in SQL '.$query2));
			$numrows2 = mysql_num_rows($result2);
			$showdelete = false;
			if ($numrows2 > 0) {
				$row2 = mysql_fetch_row($result2);
				if ($row2[0] == 0)
				{
				    $showdelete = true;
				}
				
				mysql_free_result($result2);
			}
			
			if ($showdelete == true || $version == "")
			{
				echo " <a href='app_versions.php?id=".$id."&bundleidentifier=".$bundleidentifier."' class='button' onclick='return confirm(\"Do you really want to delete this item?\");'>Delete</a>";
			}
		} else {
                echo "<a href='app_versions.php?deletecrashes=1&bundleidentifier=".$bundleidentifier."&version=".$version."' class='button redButton' onclick='return confirm(\"Do you really want to delete all items?\");'>Delete Crashes</a>";
		}
		echo "</td></tr></table></form>";
	}
	
	mysql_free_result($result);
}

mysql_close($link);

?>

<script type="text/javascript">
$(document).ready(function(){
    $.jqplot.config.enablePlugins = true;
<?php
    if ($platformticks != "") {
?>
    line1 = [<?php echo $platformvalues; ?>];
    plot1 = $.jqplot('platformdiv', [line1], {
        seriesDefaults: {
                renderer:$.jqplot.BarRenderer
            },
        axes:{
            xaxis:{
                renderer:$.jqplot.CategoryAxisRenderer,
                ticks:[<?php echo $platformticks; ?>]
            },
            yaxis:{
                min: 0,
                tickOptions:{formatString:'%.0f'}
            }
        },
        highlighter: {show: false}
    });
<?php
    }
    
    if (sizeof($crashvaluesarray) > 0) {
        foreach ($crashvaluesarray as $key => $value) {
            if ($crashvalues != "") $crashvalues = $crashvalues.", ";
            $crashvalues .= "['".$key."', ".$value."]";
        }
?>
    line1 = [<?php echo $crashvalues; ?>];
    plot1 = $.jqplot('crashdiv', [line1], {
        seriesDefaults: {showMarker:false},
        series:[
            {pointLabels:{
                show: false
            }}],
        axes:{
            xaxis:{
                renderer:$.jqplot.DateAxisRenderer,
                rendererOptions:{tickRenderer:$.jqplot.CanvasAxisTickRenderer},
                tickOptions:{formatString:'%#d-%b'}
            },
            yaxis:{
                min: 0,
                tickOptions:{formatString:'%.0f'}
            }
        },
        highlighter: {sizeAdjust: 7.5}
    });
<?php
    }
    
    if ($osticks != "") {
?>
    line1 = [<?php echo $osvalues; ?>];
    plot1 = $.jqplot('osdiv', [line1], {
        seriesDefaults: {
                renderer:$.jqplot.BarRenderer
            },
        axes:{
            xaxis:{
                renderer:$.jqplot.CategoryAxisRenderer,
                ticks:[<?php echo $osticks; ?>]
            },
            yaxis:{
                min: 0,
                tickOptions:{formatString:'%.0f'}
            }
        },
        highlighter: {show: false}
    });
<?php
    }
?>


});
</script>

</body></html>