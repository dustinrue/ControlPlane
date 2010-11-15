<?php

	/*
	 * Author: Andreas Linde <mail@andreaslinde.de>
	 *
	 * Copyright (c) 2009 Andreas Linde. All rights reserved.
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
// This script will test if the setup is fine and which functionality is available
// on the installed server
//

require_once('config.php');

echo "XMLReader: ";
if (!class_exists('XMLReader', false)) echo "FAILED"; else echo "passed";
echo "<br>";

echo "Prowl: ";
$curl_info = curl_version();	// Checks for cURL function and SSL version. Thanks Adrian Rollett!
if(!function_exists('curl_exec') || empty($curl_info['ssl_version']))
    echo "FAILED (cURL library missing or does not support SSL)";
else
{
	include('ProwlPHP.php');
    if (!class_exists('Prowl', false)) echo "FAILED"; else echo "passed";
}
echo "<br>";

echo "Boxcar: ";
$curl_info = curl_version();	// Checks for cURL function and SSL version. Thanks Adrian Rollett!
if(!function_exists('curl_exec') || empty($curl_info['ssl_version']))
    echo "FAILED (cURL library missing or does not support SSL)";
else
{
	include('class.boxcar.php');
    if (!class_exists('Boxcar', false)) echo "FAILED"; else echo "passed";
}
echo "<br>";

echo "Database access: ";
$link = mysql_connect($server, $loginsql, $passsql);
if ($link === false) echo "FAILED";
else {
    if (mysql_select_db($base) === false) echo "FAILED";
    else
        echo "passed";
        
    mysql_close($link);
}
echo "<br>";
	

?>
