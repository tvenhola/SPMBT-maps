<?php

function addZipFile($nonSanited, $zip, $filename, $padding = -1) {
	if (strlen($nonSanited) > 0) {
		$text = preg_replace('/[^\x0A\x0D\x20-\x7E]+/', '?', $nonSanited);
		$ascii = mb_convert_encoding($text, "ASCII");
		$fd = fopen("/tmp/".$filename, "w+");
		
		fwrite($fd, $ascii);
		if ($padding > strlen($text)) {
		    $paddingText = str_repeat(pack('x'), ($padding - strlen($text)));
			fwrite($fd, $paddingText);
        }
		fclose($fd);
		$zip->addFile("/tmp/".$filename, $filename);
	}
}
$id = intval($_REQUEST["id"]);
if ($id <= 0 || $id > 999) {
	echo "Invalid id";
	exit;
} else {
    $id = substr("00" . $id, -3);
}

$coords = $_REQUEST["coords"];
$desc = $_REQUEST["desc"];
$title = $_REQUEST["title"];
if (!isset($title)) {
	$title = "Autogenerated map";
}
$pattern = '/[^0-9\-\.,]+/';
$coords = preg_replace($pattern, '', $coords);
preg_match_all('/((-?\d*.\d*),(-?\d*.\d*))/', $coords, $output_array);
# print_r($coords);
$list = array_chunk($output_array[0], 4);
$args = join(',',$list[0]);

$minlevel = $_REQUEST["minlevel"];
if ($minlevel != "") {
	$minlevel = 1.0*$minlevel;
	$args = $args . " --min " . $minlevel;
}

$levelheight = $_REQUEST["levelheight"];
if ($levelheight != "") {
	$levelheight = 1.0*$levelheight;
	$args = $args . sprintf(" --level=%f", $levelheight);
}

$lockfile = "/tmp/map.lock";
$fp = fopen($lockfile, "w+");
if (flock($fp, LOCK_EX)) {  // acquire an exclusive lock
	fwrite($fp, "$args\n");
	exec("perl contour.pl --coords " . $args . " 2>&1", $output, $return_var);
	if ($return_var==0 && file_exists("/tmp/spmap999.dat")) {
		$mapfile = "spmap".$id.".dat";
		$file = tempnam("tmp", "zip");
		$zip = new ZipArchive();
		$zip->open($file, ZipArchive::OVERWRITE);
		$zip->addFile("/tmp/spmap999.dat", $mapfile);
        addZipFile($desc, $zip,"spmap".$id.".txt");
		addZipFile($title, $zip,"spmap".$id.".cmt", 308);
		$zip->close();
		header('Content-Description: File Transfer');
		header('Content-Type: application/octet-stream');
		header('Content-Disposition: attachment; filename="spmap'.$id.'.zip"');
		header('Expires: 0');
		header('Cache-Control: must-revalidate');
		header('Pragma: public');
		header('Content-Length: ' . filesize($file));
		readfile($file);
	} else {
		echo "<pre>Something went wrong, return value $return_var. Process returned:\n";
		echo join ("\n", $output);
		echo "</pre>";
	}
	fflush($fp);            // flush output before releasing the lock
	flock($fp, LOCK_UN);    // release the lock
} else {
	echo "Couldn't get the lock!";
}

fclose($fp);
?>
