<?php

class Prowl
{
	private $_version = '0.3.1';
	private $_obj_curl = null;
	private $_return_code;
	private $_remaining;
	private $_resetdate;
	
	private $_use_proxy = false;
	private $_proxy = null;
	private $_proxy_userpwd = null;

	private $_api_key = null;
	private $_prov_key = null;
	private $_api_domain = 'https://prowl.weks.net/publicapi/';
	private $_url_verify = 'verify?apikey=%s&providerkey=%s';
	private $_url_push = 'add';
	
	private $_params = array(			// Accessible params [key => maxsize]
		'apikey' 		=> 		204,		// User API Key.
		'providerkey' 	=>		40,		// Provider key.
		'priority' 		=> 		2,		// Range from -2 to 2.
		'application' 	=> 		254,	// Name of the app.
		'event' 		=> 		1024,	// Name of the event.
		'description' 	=> 		10000,	// Description of the event.
	);
	
	public function __construct($apikey=null, $verify=false, $provkey=null, $proxy=null, $userpwd=null)
	{
		$curl_info = curl_version();	// Checks for cURL function and SSL version. Thanks Adrian Rollett!
		if(!function_exists('curl_exec') || empty($curl_info['ssl_version']))
		{
			die($this->getError(10000));
		}
		
		if(isset($proxy))
			$this->_setProxy($proxy, $userpwd);
		
		if(isset($apikey) && $verify)
			$this->verify($apikey, $provkey);
		
		$this->_api_key = $apikey;
	}
	
	public function verify($apikey, $provkey)
	{
		$return = $this->_execute(sprintf($this->_url_verify, $apikey, $provkey));		
		return $this->_response($return);
	}
	
	public function push($params, $is_post=false)
	{	
		if($is_post)
			$post_params = '';
			
		$url = $is_post ? $this->_url_push : $this->_url_push . '?';
		$params = func_get_args();
		
		if(isset($this->_api_key) && !isset($params[0]['apikey']))
			$params[0]['apikey'] = $this->_api_key;
		
		if(isset($this->_prov_key) && !isset($params[0]['providerkey']))
			$params[0]['providerkey'] = $this->_prov_key;
		
		foreach($params[0] as $k => $v)
		{
			$v = str_replace("\\n","\n",$v);	// Fixes line break issue! Cheers Fr3d!
			if(!isset($this->_params[$k]))
			{
				$this->_return_code = 400;
				return false;
			}
			if(strlen($v) > $this->_params[$k])
			{
				$this->_return_code = 10001;
				return false;
			}
			
			if($is_post)
				$post_params .= $k . '=' . urlencode($v) . '&';
			else
				$url .= $k . '=' . urlencode($v) . '&';
		}
		
		if($is_post)
			$params = substr($post_params, 0, strlen($post_params)-1);
		else
			$url = substr($url, 0, strlen($url)-1);
		
		$return = $this->_execute($url, $is_post ? true : false, $params);
		
		return $this->_response($return);	
	}
		
	public function getError($code=null)
	{
		$code = (empty($code)) ? $this->_return_code : $code;
		switch($code)
		{
			case 200: 	return 'Request Successful.';	break;
			case 400:	return 'Bad request, the parameters you provided did not validate.';	break;
			case 401: 	return 'The API key given is not valid, and does not correspond to a user.';	break;
			case 405:	return 'Method not allowed, you attempted to use a non-SSL connection to Prowl.';	break;
			case 406:	return 'Your IP address has exceeded the API limit.';	break;
			case 500:	return 'Internal server error, something failed to execute properly on the Prowl side.';	break;
			case 10000:	return 'cURL library missing vital functions or does not support SSL. cURL w/SSL is required to execute ProwlPHP.';	break;
			case 10001:	return 'Parameter value exceeds the maximum byte size.';	break;
			default:	return false;	break;
		}
	}
	
	public function getRemaining()
	{
		if(!isset($this->_remaining))
			return false;
		
		return $this->_remaining;
	}
	
	public function getResetDate()
	{
		if(!isset($this->_resetdate))
			return false;
			
		return $this->_resetdate;
	}
	
	private function _execute($url, $is_post=false, $params=null)
	{
		$this->_obj_curl = curl_init($this->_api_domain . $url);
		curl_setopt($this->_obj_curl, CURLOPT_HEADER, 0);
		curl_setopt($this->_obj_curl, CURLOPT_USERAGENT, "ProwlPHP/" . $this->_version);
		curl_setopt($this->_obj_curl, CURLOPT_HTTPAUTH, CURLAUTH_ANY);
		curl_setopt($this->_obj_curl, CURLOPT_SSL_VERIFYPEER, false);
		curl_setopt($this->_obj_curl, CURLOPT_RETURNTRANSFER, 1);
		
		if($is_post)
		{
			curl_setopt($this->_obj_curl, CURLOPT_POST, 1);
			curl_setopt($this->_obj_curl, CURLOPT_POSTFIELDS, $params);
		}
		
		if($this->_use_proxy)
		{
			curl_setopt($this->_obj_curl, CURLOPT_HTTPPROXYTUNNEL, 1);
			curl_setopt($this->_obj_curl, CURLOPT_PROXY, $this->_proxy);
			curl_setopt($this->_obj_curl, CURLOPT_PROXYUSERPWD, $this->_proxy_userpwd); 
		}
		
		$return = curl_exec($this->_obj_curl);
		curl_close($this->_obj_curl);
		return $return;
	}
	
	private function _response($return)
	{
		if($return===false)
		{
			$this->_return_code = 500;
			return false;
		}
		
		$response = new SimpleXMLElement($return);
		
		if(isset($response->success))
		{
			$this->_return_code = (int)$response->success['code'];
			$this->_remaining = (int)$response->success['remaining'];
			$this->_resetdate = (int)$response->success['resetdate'];
		}
			else
		{
			$this->_return_code = $response->error['code'];
		}
		
		switch($this->_return_code)
		{
			case 200: 	return true;	break;
			default:	return false;	break;
		}
		
		unset($response);
	}
	
	private function _setProxy($proxy, $userpwd=null)
	{
		if(strlen($proxy) > 0)
		{
			$this->_use_proxy = true;
			$this->_proxy = $proxy;
			$this->_proxy_userpwd = $userpwd;
		}
	}
}

?>