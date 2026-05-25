<?php
// Database configuration
$servername = "localhost";
$username = "your_username";
$password = "your_password";
$dbname = "your_database_name";

// Create connection ($conx used by sql.php, sync_upload.php, sync_receiver.php)
$conx = new mysqli($servername, $username, $password, $dbname);

if ($conx->connect_error) {
    die("Connection failed: " . $conx->connect_error);
}

$conx->set_charset("utf8");

// Backward compatibility
$conn = $conx;

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}
