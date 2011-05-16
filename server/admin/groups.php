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
parse_parameters(',bundleidentifier,version,');

if (!isset($bundleidentifier)) $bundleidentifier = "";
if (!isset($version)) $version = "";

if ($bundleidentifier == "") die(end_with_result('Wrong parameters'));
if ($version == "") die(end_with_result('Wrong parameters'));

show_header('- Crash Patterns');

echo '<h2>';
if (!$acceptallapps)
	echo '<a href="app_name.php">Apps</a> - ';

echo create_link($bundleidentifier, 'app_versions.php', false, 'bundleidentifier').' - '.create_link('Version '.$version, 'groups.php', false, 'bundleidentifier,version').'</h2>';

$osticks = "";
$osvalues = "";

$crashvaluesarray = array();
$crashvalues = "";


// get the amount of crashes over time

$query = "SELECT timestamp FROM ".$dbcrashtable."  WHERE bundleidentifier = '".$bundleidentifier."' AND version = '".$version."' ORDER BY timestamp desc";
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


$cols2 = '<colgroup><col width="320"/><col width="320"/><col width="320"/></colgroup>';
echo '<table>'.$cols2.'<tr><th>Platform Overview</th><th>Crashes over time</th><th>System OS Overview</th></tr>';

echo "<tr><td><div id=\"platformdiv\" style=\"height:280px;width:310px; \"></div></td>";
echo "<td><div id=\"crashdiv\" style=\"height:280px;width:310px; \"></div></td>";
echo "<td><div id=\"osdiv\" style=\"height:280px;width:310px; \"></div></td></tr>"; 

// get the amount of crashes per system version
$crashestime = true;

$osticks = "";
$osvalues = "";
$whereclause = "";

$query2 = "SELECT systemversion, COUNT(systemversion) FROM ".$dbcrashtable.$whereclause." WHERE bundleidentifier = '".$bundleidentifier."' AND version = '".$version."' group by systemversion order by systemversion desc";
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
$query = "SELECT platform, COUNT(platform) FROM ".$dbcrashtable." WHERE bundleidentifier = '".$bundleidentifier."' AND version = '".$version."' AND platform != \"\" group by platform order by platform desc";
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


// START Group Deta
$cols2 = '<colgroup><col width="950"/></colgroup>';
echo '<table>'.$cols2.'<tr><th>Group Details</th></tr>';
echo '<tr><td>';
            
show_search("", -1, true, "");

echo " <a href=\"javascript:deleteGroups('$bundleidentifier','$version')\" style=\"float: right; margin-top:-35px;\" class=\"button redButton\" onclick=\"return confirm('Do you really want to delete all items?');\">Delete All</a>";

echo '</tr></td></table>';
// END Group Details


// START Group Listing
$cols = '<colgroup><col width="90"/><col width="50"/><col width="100"/><col width="180"/><col width="360"/><col width="190"/></colgroup>';

echo '<table>'.$cols;
echo "<tr><th>Pattern</th><th>Amount</th><th>Last Update</th><th>Assigned Fix Version</th><th>Description</th><th>Actions</th></tr>";
echo '</table>';

echo '<div id="groups">';

// get all groups
$query = "SELECT fix, pattern, amount, id, description, latesttimestamp FROM ".$dbgrouptable." WHERE bundleidentifier = '".$bundleidentifier."' AND affected = '".$version."' ORDER BY fix desc, amount desc, pattern asc";
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
		$lastupdate = $row[5];
		
		if ($notify_amount_group > 1 && $amount >= $notify_amount_group)
		{
			$amount = "<b><font color='red'>".$amount."</font></b>";
		}
		
    echo "<form name='groupmetadata".$groupid."' action='' method='get'>";
		echo '<table>'.$cols;
		$patterntitle = str_replace("%","\n",$pattern);
    if (strlen($patterntitle) > 54) {
      $patterntitle = substr($patterntitle,0,50)."...";
    }

		echo "<tr id='grouprow".$groupid."'><td><a href='crashes.php?groupid=".$groupid."&bundleidentifier=".$bundleidentifier."&version=".$version."'>".$patterntitle."</a></td><td>".$amount."</td><td>";
		
		if ($lastupdate != 0) {
      $timestring = date("Y-m-d H:i:s", $lastupdate);
			if (time() - $lastupdate < 60*24*24)
				echo "<font color='".$color24h."'>".$timestring."</font>";
			else if (time() - $lastupdate < 60*24*24*2)
				echo "<font color='".$color48h."'>".$timestring."</font>";
			else if (time() - $lastupdate < 60*24*24*3)
				echo "<font color='".$color72h."'>".$timestring."</font>";
			else
				echo "<font color='".$colorOther."'>".$timestring."</font>";
		} else {
    	echo "-";
    }
        	
		echo '</td><td><input type="text" id="fixversion'.$groupid.'" name="fixversion" size="20" maxlength="20" value="'.$fix.'"/></td><td><textarea id="description'.$groupid.'" cols="50" rows="2" name="description" class="description">'.$description.'</textarea></td><td>';
    echo "<a href=\"javascript:updateGroupMeta(".$groupid.",'".$bundleidentifier."')\" class='button'>Update</a> ";
		echo "<a href='actionapi.php?action=downloadcrashid&groupid=".$groupid."' class='button'>Download</a> ";
		$issuelink = currentPageURL();
		$issuelink = substr($issuelink, 0, strrpos($issuelink, "/")+1);
		echo create_issue($bundleidentifier, $issuelink.'crashes.php?groupid='.$groupid.'&bundleidentifier='.$bundleidentifier.'&version='.$version);
		
        echo " <a href='javascript:deleteGroupID(".$groupid.")' class='button redButton' onclick='return confirm(\"Do you really want to delete this item?\");'>Delete</a></td></tr>";
		echo '</table>';
		echo '</form>';
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
		echo '<tr><td><a href="crashes.php?bundleidentifier='.$bundleidentifier.'&version='.$version.'">Ungrouped</a></td>';
		echo '<td>'.$amount.'</td><td></td><td></td><td></td>';
        echo "<td><a href='regroup.php?bundleidentifier=".$bundleidentifier."&version=".$version."' class='button'>Re-Group</a>";
		echo "<a href='groups.php?bundleidentifier=".$bundleidentifier."&version=".$version."&groupid=0' class='button redButton' onclick='return confirm(\"Do you really want to delete this item?\");'>Delete</a></td></tr>";
		echo '</table>';
	}
	mysql_free_result($result);
}

mysql_close($link);

?>
</div>

<script type="text/javascript">
$(document).ready(function(){
    $.jqplot.config.enablePlugins = true;

<?php
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