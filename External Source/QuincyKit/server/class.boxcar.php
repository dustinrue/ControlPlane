<?php
// by gpetit, http://help.boxcar.io/discussions/developers/15-php-class-to-send-notification-in-boxcar

	class Boxcar {

		private $username;
		private $password;

		public function __construct($username = "", $password = "") {

            $this->username		= $username;
            $this->password		= $password;
        }
        
		public function send($sender, $message) {

			$rdmint = rand();
			$ch = curl_init();
			curl_setopt($ch, CURLOPT_HTTPAUTH, CURLAUTH_ANY);
			curl_setopt($ch, CURLOPT_USERPWD, $this->username.':'.$this->password);
			curl_setopt($ch, CURLOPT_URL, 'https://boxcar.io/notifications');
			curl_setopt($ch, CURLOPT_POST, 3);
			curl_setopt($ch, CURLOPT_POSTFIELDS, 'notification[from_screen_name]='.urlencode(stripslashes($sender)).'&notification[message]='.urlencode(stripslashes($message)).($id ? '&notification[from_remote_service_id]='.$rdmint : ''));
			$return = curl_exec($ch);

			$httpcode = curl_getinfo($ch, CURLINFO_HTTP_CODE);

			curl_close($ch);

			# Invalid username/password
			if($httpcode == "401"):

				return array("success" => "n",
							"error" => "Invalid username/password",
							"error_code" => "401");

			# No application/event defined
			elseif($httpcode == "400"):

				return array("success" => "n",
							"error" => "No application/event defined",
							"error_code" => "400");

			# All ok!
			endif;			

			return array("success" => "y",
						"error" => "",
						"error_code" => "");
		}

	};

?>