<?php

	/*
	* Author: Andreas Linde <mail@andreaslinde.de>
	*
	* Copyright (c) 2009-2011 Andreas Linde.
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
// Symbolicate a list of crash logs locally
//
// This script symbolicates crash log data on a local machine by
// querying a remote server for a todo list of crash logs and
// using remote script to fetch the crash log data and also update
// the very same on the remote servers
//

include "serverconfig.php";

function doPost($postdata)
{
    global $updatecrashdataurl, $hostname, $webuser, $webpwd;
    
	$uri = $updatecrashdataurl;
	$host = $hostname;
	$handle = fsockopen($host, 80, $errno, $errstr); 
	if (!$handle) { 
		return 'error'; 
	} 
	else { 
		$temp = "POST ".$uri." HTTP/1.1\r\n"; 
		$temp .= "Host: ".$host."\r\n"; 
		$temp .= "User-Agent: PHP Script\r\n"; 
		$temp .= "Content-Type: application/x-www-form-urlencoded\r\n";
		if ($webuser != "" && $webpwd != "")
    		$temp .= "Authorization: Basic ".base64_encode($webuser.":".$webpwd)."\r\n"; 
		$temp .= "Content-Length: ".strlen($postdata)."\r\n"; 
		$temp .= "Connection: close\r\n\r\n"; 
		$temp .= $postdata; 
		$temp .= "\r\n\r\n";
		
		fwrite($handle, $temp); 
		
		$response = '';
		
		while (!feof($handle)) 
			$response.=fgets($handle, 128); 
			
		$response=split("\r\n\r\n",$response);
		
		$header=$response[0]; 
		$responsecontent=$response[1]; 
		
		if(!(strpos($header,"Transfer-Encoding: chunked")===false))
		{
			$aux=split("\r\n",$responsecontent); 
			for($i=0;$i<count($aux);$i++) 
				if($i==0 || ($i%2==0)) 
					$aux[$i]=""; 
			$responsecontent=implode("",$aux); 
		} 
		return chop($responsecontent); 
	} 
} 
    

if ($webuser != "" && $webpwd != "")
{
    $downloadtodosurl = "http://".$webuser.":".$webpwd."@".$hostname.$downloadtodosurl;
    $getcrashdataurl = "http://".$webuser.":".$webpwd."@".$hostname.$getcrashdataurl;
} else {
    $downloadtodosurl = "http://".$hostname.$downloadtodosurl;
    $getcrashdataurl = "http://".$hostname.$getcrashdataurl;
}


// get todo list from the server
$content = file_get_contents($downloadtodosurl);

$error = false;

if ($content !== false && strlen($content) > 0)
{
	echo "To do list: ".$content."\n\n";
	$crashids = split(',', $content);
	foreach ($crashids as $crashid)
	{
		$filename = $crashid.".crash";
		$resultfilename = "result_".$crashid.".crash";
	
		echo "Processing crash id ".$crashid." ...\n";
	
	
		echo "  Downloading crash data ...\n";
	
		$log = file_get_contents($getcrashdataurl.$crashid);
	
		if ($log !== false && strlen($log) > 0)
		{
			echo "  Writing log data into temporary file ...\n";
				
			$output = fopen($filename, 'w+');
			fwrite($output, $log);
			fclose($output);
		
		
			echo "  Symbolicating ...\n";
			
			exec('perl ./symbolicatecrash.pl -o '.$resultfilename.' '.$filename);
	
			unlink($filename);
			
			if (file_exists($resultfilename) && filesize($resultfilename) > 0)
			{
				echo "  Sending symbolicated data back to the server ...\n";
				
				$resultcontent = file_get_contents($resultfilename);

				$post_results = doPost('id='.$crashid.'&log='.urlencode($resultcontent));
				
				if (is_string($post_results))
				{
					if ($post_results == 'success')
				 		echo '  SUCCESS!';
			    }

			}


			echo "  Deleting temporary files ...\n";

			unlink($resultfilename);
		}
	}
	
	echo "\nDone\n\n";
	
} else if ($content !== false) {
	echo "Nothing to do.\n\n";
}


?>