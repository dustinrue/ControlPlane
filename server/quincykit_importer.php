<?php

require_once('config.php');

if ( ini_get('pcre.backtrack_limit') <= 950000 )
ini_set('pcre.backtrack_limit', 950000);
if ( ini_get('pcre.recursion_limit') <= 350000 )
ini_set('pcre.recursion_limit', 350000);

# Are we running from the command line or are we being included
$included = false;

if (isset($body)) {
  $included = true;
  error_log("We're being included");
} else {

  if ($argc != 2 || in_array($argv[1], array('--help', '-help', '-h', '-?'))) {
  ?>

  This script will import mbox files into QuincyKit. It expects to be passed a folder.

    Usage:
    <?php echo $argv[0]; ?> <folder to import>

  <?php
  exit(0);
  }
  
}


function parseblock($matches, $appString) {
  $result_offset = "";
  $depth = 0;
  //make sure $matches[1] exists
  if (is_array($matches) && count($matches) >= 2) {
    $result = explode("\n", $matches[1]);
    foreach ($result as $line) {
      // search for the first occurance of the application name
      if (strpos($line, $appString) !== false && strpos($line, "uncaught_exception_handler (PLCrashReporter.m:") === false && $depth <= 10) {
        preg_match('/[0-9]+\s+[^\s]+\s+([^\s]+) /', $line, $matches);

        if (count($matches) >= 2) {
          if ($result_offset != "")
            $result_offset .= "%";
          $result_offset .= $matches[1];
          $depth++;
        }
      }
    }
  }

  return $result_offset;
}

function xml_for_result($result) {
	return 'Result:' . $result; 
}

$dir = '';

if ($included) {
  # make a unique folder name
  $crash_folder = 'crashes/' . uniqid();
  mkdir($crash_folder) or die('Failed to create folder');
  
  # write the contents out to the folder
  file_put_contents($crash_folder . '/crash.txt', $body);

  $dir = $crash_folder;
} else {
  $dir = $argv[1];
}

#Check to make sure we got a folder
if (!is_dir($dir)) {
  error_log($dir . " is not a folder\n");
  exit(1);
}

$folder = dir($dir);

$crash = array();

$link = mysql_connect($server, $loginsql, $passsql) or die(xml_for_result(FAILURE_DATABASE_NOT_AVAILABLE));
mysql_select_db($base) or die(xml_for_result(FAILURE_DATABASE_NOT_AVAILABLE));

while (false !== ($file = $folder->read())) {
  if (is_dir($dir . '/' . $file)) continue;
  error_log("Parsing " . $file . ": ");
  
  $contents = file_get_contents($dir . '/' . $file);

  # Are we looking at an exception and not a crash?
  preg_match('/Exception:\s+(.*)/', $contents, $m);
  if (count($m) > 0) {
    error_log("Exception report\n");
    continue;
  }

  if (!$included) {
    # Is this crash report unusually large?
    preg_match('/Content-Length:\s+(\d*)/', $contents, $m);
    if (!count($m)) {
      error_log("No Content Length, Skipping...\n");
      continue;
    } else if ($m[1] > 1000000) {
      error_log("Report too large, Skipping...\n");
      continue;
    }
  }

  $crash['userid'] = "";
  $crash['platform'] = "";
  $crash['description'] = "";

  # User ID
  preg_match('/Anonymous UUID:\s+(.*)/', $contents, $m);
  if (count($m)) {
    $crash['userid'] = $m[1];
  }

  # Contact
  preg_match('/From: (.*)[\r\n]Comments/', $contents, $m);
  if (!count($m)) {
    preg_match('/From: (.*)[\r\n]/', $contents, $m);
    if (!count($m)) {
      error_log("No Contact, Skipping...\n");
      continue;
    }
  }
  $crash['contact'] = $m[1];

  # Bundle ID
  preg_match('/^Identifier:\s+(.*)/m', $contents, $m);
  if (!count($m)) {
    error_log("No Bundle ID, Skipping...\n");
    continue;
  }
  $crash['bundleidentifier'] = $m[1];
  
  # App name
  preg_match('/Process:\s+(.*) (\[\d+\])/', $contents, $m);
  if (!count($m)) {
    error_log("No Application Name, Skipping...\n");
    continue;
  }
  $crash['applicationname'] = $m[1];
  
  # App Version
  preg_match('/\nVersion:\s+(.*) \(.*\)/', $contents, $m);
  if (!count($m)) {
    error_log("No Version, Skipping...\n");
    continue;
  }
  $crash['version'] = $m[1];
  
  # OS Version
  preg_match('/OS Version:\s+[a-zA-Z\s]+ ([0-9\.]+)/', $contents, $m);
  if (!count($m)) {
    error_log("No OS Version, Skipping...\n");
    continue;
  }
  $crash['systemversion'] = $m[1];

  # Platform
  preg_match('/Code Type:\s+([a-zA-Z0-9\-]+)/', $contents, $m);
  if (count($m)) {
    $crash['platform'] = $m[1];
  }

  # Comments
  preg_match('/Comments:\s+(.*)[\n\r]System:/ms', $contents, $m);
  if (count($m)) {
    $crash['description'] = $m[1];
  }
  
  # Date
  if (!$included) {
    preg_match('/Date: (.*)/', $contents, $m);
    if (!strtotime($m[1])) {
      error_log("Bad Date, skipping\n");
      continue;
    }
    $crash['date'] = date("Y-m-d H:i:s", strtotime($m[1]));
  } else {
    $crash['date'] = date("Y-m-d H:i:s");
  }

  # Cleanup report for submission
  if ($included) {
    $crash['logdata'] = $contents;
  } else {
    $crash['logdata'] = preg_replace('/^From.*--- Crash Log: ---[\r\n]/ms','', $contents);
  }
  
  if (!$crash['logdata']) {
    if (preg_last_error() == PREG_NO_ERROR) {
        print 'There is no error.';
    }
    else if (preg_last_error() == PREG_INTERNAL_ERROR) {
        print 'There is an internal error!';
    }
    else if (preg_last_error() == PREG_BACKTRACK_LIMIT_ERROR) {
        print 'Backtrack limit was exhausted!';
    }
    else if (preg_last_error() == PREG_RECURSION_LIMIT_ERROR) {
        print 'Recursion limit was exhausted!';
    }
    else if (preg_last_error() == PREG_BAD_UTF8_ERROR) {
        print 'Bad UTF8 error!';
    }
    else if (preg_last_error() == PREG_BAD_UTF8_ERROR) {
        print 'Bad UTF8 offset error!';
    }
    
    error_log("Crash data is missing after pruning\n");
    exit(1);
  }
  
	// this stores the offset which we need for grouping
	$crash_offset = "";
	$appcrashtext = "";

  preg_match('/Crashed Thread:\s+Unknown/',$crash["logdata"], $m);
  if (count($m)) {
    error_log("Crash Thread Unknown\n");
    continue;
  }

  preg_match('/Dyld Error Message:/',$crash["logdata"], $m);
  if (count($m)) {
    error_log("Dyld Error Message, skipping\n");
    continue;
  }

	preg_match('%Application Specific Information:.*?\n(.*?)\n\n%is', $crash["logdata"], $appcrashinfo);
	if (is_array($appcrashinfo) && count($appcrashinfo) == 2) {
    $appcrashtext = str_replace("\\", "", $appcrashinfo[1]);
    $appcrashtext = str_replace("'", "\'", $appcrashtext);
  }


	// extract the block which contains the data of the crashing thread
	preg_match('%Thread [0-9]+ Crashed:.*?\n(.*?)\n\n%is', $crash["logdata"], $matches);
	
  $crash_offset = parseblock($matches, $crash["applicationname"]);	
  if ($crash_offset == "") {
      $crash_offset = parseblock($matches, $crash["bundleidentifier"]);
  }
  if ($crash_offset == "") {
    # Catches our frameworks
    $crash_offset = parseblock($matches, 'com.panic');
  }
  if ($crash_offset == "") {
    # Catches Apple's frameworks
    $crash_offset = parseblock($matches, 'com.apple');
  }

  if ($crash_offset == "") {
      error_log("Unable to locate crash offset, trying second approach: ");
      preg_match('%Thread [0-9]+ Crashed(.*)%is', $crash["logdata"], $matches);
      $crash_offset = parseblock($matches, $crash["applicationname"]);
  }
  if ($crash_offset == "") {
      $crash_offset = parseblock($matches, $crash["bundleidentifier"]);
  }
  if ($crash_offset == "") {
      # Catches our frameworks
      $crash_offset = parseblock($matches, 'com.panic');
  }
  if ($crash_offset == "") {
    # Catches Apple's frameworks
    $crash_offset = parseblock($matches, 'com.apple');
  }

  if ($crash_offset == "" && $crash['version'] == '???') {
    error_log("Unable to determine crash offset and version unknown\n");
    continue;
  } else if ($crash_offset == "" ) {
    error_log("Unable to determine crash offset\n");
    exit(1);
  }

  // print_r($crash_offset);

 	// check if the version is already added and the status of the version and notify status
	$query = "SELECT id, status, notify FROM ".$dbversiontable." WHERE bundleidentifier = '".$crash["bundleidentifier"]."' and version = '".$crash["version"]."'";
	$result = mysql_query($query) or die(xml_for_result(FAILURE_SQL_CHECK_VERSION_EXISTS));

	$numrows = mysql_num_rows($result);
	if ($numrows == 0) {
    // version is not available, so add it with status VERSION_STATUS_DISCONTINUED
		$query = "INSERT INTO ".$dbversiontable." (bundleidentifier, version, status, notify) values ('".$crash["bundleidentifier"]."', '".$crash["version"]."', ".VERSION_STATUS_DISCONTINUED.", ".NOTIFY_OFF.")";
		$result = mysql_query($query) or die(xml_for_result(FAILURE_SQL_ADD_VERSION));
	} else {
    $row = mysql_fetch_row($result);
		$crash["version_status"] = $row[1];
		$notify = $row[2];
		mysql_free_result($result);
	}

	// stores the group this crashlog is associated to, by default to none
	$log_groupid = 0;

  // if the offset string is not empty, we try a grouping
  if (strlen($crash_offset) > 0) {
    // get all the known bug patterns for the current app version
    $query = "SELECT id, fix, amount, description FROM ".$dbgrouptable." WHERE bundleidentifier = '".$crash["bundleidentifier"]."' and affected = '".$crash["version"]."' and pattern = '".mysql_real_escape_string($crash_offset)."'";
    $result = mysql_query($query) or die(xml_for_result(FAILURE_SQL_FIND_KNOWN_PATTERNS));

    $numrows = mysql_num_rows($result);

    if ($numrows == 1) {
      // assign this bug to the group
      $row = mysql_fetch_row($result);
      $log_groupid = $row[0];
      $amount = $row[2];
      $desc = $row[3];

      mysql_free_result($result);

      // update the occurances of this pattern
      $query = "UPDATE ".$dbgrouptable." SET amount=amount+1, latesttimestamp = ".time()." WHERE id=".$log_groupid;
      $result = mysql_query($query) or die(xml_for_result(FAILURE_SQL_UPDATE_PATTERN_OCCURANCES));

      if ($desc != "" && $appcrashtext != "") {
        $desc = str_replace("'", "\'", $desc);
        if (strpos($desc, $appcrashtext) === false) {
          $appcrashtext = $desc."\n-----------------------\n".$appcrashtext;
          $query = "UPDATE ".$dbgrouptable." SET description='".$appcrashtext."' WHERE id=".$log_groupid;
          $result = mysql_query($query) or die(end_with_result('Error in SQL '.$query));
        }
      }                       
    } else if ($numrows == 0) {
      // create a new pattern for this bug and set amount of occurrances to 1
      $query = "INSERT INTO ".$dbgrouptable." (bundleidentifier, affected, pattern, amount, latesttimestamp, description) values ('".$crash["bundleidentifier"]."', '".$crash["version"]."', '".$crash_offset."', 1, ".time().", '".$appcrashtext."')";
      $result = mysql_query($query) or die(xml_for_result(FAILURE_SQL_ADD_PATTERN));

      $log_groupid = mysql_insert_id($link);
    }
  }

  // now insert the crashlog into the database
  $query = "INSERT INTO ".$dbcrashtable." (userid, contact, bundleidentifier, applicationname, systemversion, platform, senderversion, version, description, log, groupid, timestamp, jailbreak) values ('".$crash["userid"]."', '".$crash["contact"]."', '".$crash["bundleidentifier"]."', '".$crash["applicationname"]."', '".$crash["systemversion"]."', '".$crash["platform"]."', '".$crash["version"]."', '".$crash["version"]."', '".mysql_real_escape_string($crash["description"])."', '".mysql_real_escape_string($crash["logdata"])."', '".$log_groupid."', '".$crash['date']."', 0)";
  $result = mysql_query($query) or die("Error: " . mysql_error());

//  print_r($crash);

  error_log("done!\n");
}
  

$folder->close();
mysql_close($link);

if ($included) {
#  unlink($crash_folder . '/crash.txt');
#  rmdir($crash_folder);
}

?>