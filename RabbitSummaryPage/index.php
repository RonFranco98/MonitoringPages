<?php
	echo "<h1 style='text-align:center'>rabbit monitoring</h1>";
	echo "<link href='style.css' rel='StyleSheet'>";
	
	$maxUnacknowledged = intval($_GET["maxUnacknowledged"]);
	$totalStatus = "ALL IS GOOD";
	
	createTable("classified" , "classified" , "classified" , "classified");
	
		
	function createTable($address , $user , $pass , $tableName){
		$auth = base64_encode("$user:$pass");
		$context = stream_context_create([
			"http" => [
				"header" => "Authorization: Basic $auth"
			]
		]);
		$queues = json_decode(file_get_contents("http://$address/api/queues", false, $context ));
		echo "
		<table>
			<caption><h2>$tableName</h2></caption>
			<tr>
				<th>queue name</th>
				<th>total messages</th>
				<th>ready messages</th>
				<th>unacknowledged messages</th>
				<th>status</th>
			</tr>
		";
		foreach($queues as $queue){
			global $maxUnacknowledged,$totalStatus;
			$queueName = $queue->name;
			$ready = $queue->messages_ready;
			$unacknowledged = $queue->messages_unacknowledged;
			$total = $unacknowledged + $ready;
			$status = "OK";
			$RBGValue = 255 - intval($unacknowledged/$maxUnacknowledged);
			
			if($unacknowledged > $maxUnacknowledged){
				$totalStatus = "one or more queue is bad";
				$status = "BAD";
				if($RBGValue < 0){
					$RBGValue = 0;
				}
				echo "
				<tr style='background-color:rgb(255,$RBGValue,$RBGValue)'>
					<td>$queueName</td>
					<td>$total</td>
					<td>$ready</td>
					<td>$unacknowledged</td>
					<td>$status</td>
				</tr>
			";
			}
			
			
		}
		echo "</table>";
	}
	echo "Final status: $totalStatus";
?>